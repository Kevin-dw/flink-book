# flink 1.12源码分析

我们找一个最简单的flink程序word count来分析源码。

```java
public class WordCount {

	public static void main(String[] args) throws Exception {

        // 获取运行时环境
		final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

		env.setParallelism(1);
		DataStream<String> text = env.fromElements("hello world", "hello world");

		DataStream<Tuple2<String, Integer>> counts = text
			.flatMap(new Tokenizer())
			.setParallelism(1)
			.filter(r -> r.f0.equals("hello"))
			.setParallelism(2)
			.keyBy(r -> r.f0)
			.reduce(
				new ReduceFunction<Tuple2<String, Integer>>() {
					@Override
					public Tuple2<String, Integer> reduce(Tuple2<String, Integer> value1, Tuple2<String, Integer> value2) throws Exception {
						return Tuple2.of(value1.f0, value1.f1 + value2.f1);
					}
				}
			)
			.setParallelism(2);

		counts.print();

		env.execute("Streaming WordCount");
	}

	public static final class Tokenizer implements FlatMapFunction<String, Tuple2<String, Integer>> {

		@Override
		public void flatMap(String value, Collector<Tuple2<String, Integer>> out) {
			String[] tokens = value.toLowerCase().split("\\W+");

			for (String token : tokens) {
				if (token.length() > 0) {
					out.collect(new Tuple2<>(token, 1));
				}
			}
		}
	}

}
```

程序执行的流程图

```
+----------------+
| 获取运行时环境 |
+----------------+
        |
        |
        v
+---------------+
| 构建数据流图  |
+---------------+
       |
       |
       v
+-------------+
|  执行程序   |
+-------------+
```

在上面的word count程序中， 我们首先获取了运行时环境。

```java
StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
```

然后使用flink的DataStream API构建了数据流图。

```java
DataStream<Tuple2<String, Integer>> counts = text
	.flatMap(new Tokenizer())
	.setParallelism(1)
	.filter(r -> r.f0.equals("hello"))
	.setParallelism(2)
	.keyBy(r -> r.f0)
	.reduce(
		new ReduceFunction<Tuple2<String, Integer>>() {
			@Override
			public Tuple2<String, Integer> reduce(Tuple2<String, Integer> value1, Tuple2<String, Integer> value2) throws Exception {
				return Tuple2.of(value1.f0, value1.f1 + value2.f1);
			}
		}
	)
	.setParallelism(2);

counts.print();
```

然后开始执行程序

```java
env.execute("flink job");
```

## 获取运行时环境

我们使用`getExecutionEnvironment()`方法获取了运行时环境。运行时环境是一个类，也就是`StreamExecutionEnvironment.java`这个文件。

这个运行时环境类有很多属性和方法，那么这里我们重点关注一个属性：

```java
protected final List<Transformation<?>> transformations = new ArrayList<>();
```

这个`transformations`是一个链表。那么里面保存了什么呢？

```
0 = {OneInputTransformation@2148} "OneInputTransformation{id=2, name='Flat Map', outputType=Java Tuple2<String, Integer>, parallelism=1}"
1 = {OneInputTransformation@2149} "OneInputTransformation{id=3, name='Filter', outputType=Java Tuple2<String, Integer>, parallelism=2}"
2 = {OneInputTransformation@2150} "OneInputTransformation{id=5, name='Keyed Reduce', outputType=Java Tuple2<String, Integer>, parallelism=2}"
3 = {SinkTransformation@2151} "SinkTransformation{id=6, name='Print to Std. Out', outputType=null, parallelism=1}"
```

我们可以看到链表中的每一个元素都是一个转换算子，并且里面有算子的名字、输出类型、并行度等信息。

例如索引为2的元素是一个`Keyed Reduce`转换，输出类型是`Tuple2<String, Integer>`，并行度是2。

那么这个`transformations`数组是如何构建出来的呢？

## 使用DataStream API构建transformations

我们使用了以下代码来构建transformations数组

```java
stream.flatMap(...).keyBy().reduce(...);
```

例如我们分析一下flatMap算子, 点击flatMap进入源码。

```java
public <R> SingleOutputStreamOperator<R> flatMap(FlatMapFunction<T, R> flatMapper) {

    // 获取算子的输出类型
	TypeInformation<R> outType = TypeExtractor.getFlatMapReturnTypes(clean(flatMapper),
			getType(), Utils.getCallLocationName(), true);

    // 将flatMap算子添加到transformations数组中，请点击`flatMap`
	return flatMap(flatMapper, outType);
}
```

可以看到是

```java
public <R> SingleOutputStreamOperator<R> flatMap(FlatMapFunction<T, R> flatMapper, TypeInformation<R> outputType) {
    // 点击`transform`
	return transform("Flat Map", outputType, new StreamFlatMap<>(clean(flatMapper)));
}
```

来到了

```java
// 点击`doTransform`
return doTransform(operatorName, outTypeInfo, SimpleOperatorFactory.of(operator));
```

来到了`doTransform`函数，里面有一句代码很重要

```java
getExecutionEnvironment().addOperator(resultTransform);
```

可以注意到这行代码中有一个`addOperator`方法，这个方法将`flatMap`作为操作符添加到`transformations`数组中。

因为`addOperator`的代码是

```java
this.transformations.add(transformation);
```

将flatMap算子添加到了transformations中。


那么从哪里开始看起呢？从`execute`开始看起。

也就是以下一行：

```java
env.execute("flink job");
```

当我们点击`execute`时，代码跳转到了

`StreamExecutionEnvironment.java`的`1819`行

我们来看函数体中，也就是`1822`行代码。

```java
return execute(getStreamGraph(jobName));
```

这里我们可以看到执行代码的步骤是：

1. `getStreamGraph`函数用来获取作业的`流图`。
2. `execute`用来执行流图。

我们都知道，flink里面图的数据结构的转换模式是：

```
+----------------+
|  StreamGraph   |
+----------------+
        |
        |
        v
+----------------+
|    JobGraph    |
+----------------+
        |
        |
        v
+----------------+
| ExecutionGraph |
+----------------+
```
 
也就是说先将StreamGraph转换成JobGraph，然后再从JobGraph转换成ExecutionGraph。    

而`getStreamGraph`就是用来获取`StreamGraph`数据结构的。

当我们点击`getStreamGraph`时，代码会跳转到当前文件的`1975`行，而第`1976`行是：

```java
return getStreamGraph(jobName, true);
```

看的出来，还要继续点击，继续点击来到了同文件的`1990`行，以下是函数体

```java
1990    public StreamGraph getStreamGraph(String jobName, boolean clearTransformations) {
1991        StreamGraph streamGraph = getStreamGraphGenerator().setJobName(jobName).generate();
1992        if (clearTransformations) {
1993            this.transformations.clear();
1994        }
1995        return streamGraph;
1996    }
```

第1991行代码，产生了一个StreamGraph，而第1995行代码，返回了这个StreamGraph。

## 如何生成StreamGraph

我们可以看一下第1991行

```java
1991  StreamGraph streamGraph = getStreamGraphGenerator().setJobName(jobName).generate();
```

这里面有分成了两步

1. `getStreamGraphGenerator`用来获取`StreamGraph`的生成器。
2. `generate()`用来生成`StreamGraph`。

点击`getStreamGraphGenerator`进去一探究竟。

```java
1998    private StreamGraphGenerator getStreamGraphGenerator() {
1999        if (transformations.size() <= 0) {
2000            throw new IllegalStateException("No operators defined in streaming topology. Cannot execute.");
2001        }

2003        final RuntimeExecutionMode executionMode =
2004                configuration.get(ExecutionOptions.RUNTIME_MODE);

2006        return new StreamGraphGenerator(transformations, config, checkpointCfg, getConfiguration())
2007            .setRuntimeExecutionMode(executionMode)
2008            .setStateBackend(defaultStateBackend)
2009            .setChaining(isChainingEnabled)
2010            .setUserArtifacts(cacheFile)
2011            .setTimeCharacteristic(timeCharacteristic)
2012            .setDefaultBufferTimeout(bufferTimeout);
2013    }
```

从2006行开始，对StreamGraph进行了一系列的配置。

然后，我们需要点击进入1991行的`generate`函数去一探究竟。

```java
252  public StreamGraph generate() {
253     streamGraph = new StreamGraph(executionConfig, checkpointConfig, savepointRestoreSettings);
254     shouldExecuteInBatchMode = shouldExecuteInBatchMode(runtimeExecutionMode);
255     configureStreamGraph(streamGraph);
256
257     alreadyTransformed = new HashMap<>();
258
259     for (Transformation<?> transformation: transformations) {
260         transform(transformation);
261     }
262
263     final StreamGraph builtStreamGraph = streamGraph;
264
265     alreadyTransformed.clear();
266     alreadyTransformed = null;
267     streamGraph = null;
268
269     return builtStreamGraph;
270  }
```

第253行实例化了一个`StreamGraph`，而最关键的就是第260行。这一行代码将`transformation`进一步做了转换。

`transform`函数将`transformations`这个列表，转换成了一个整数数组。

这个整数数组是什么呢？这个整数数组里面包含了我们将算子转换成了的整数ID。

例如，我们的代码

```java
env.fromElements(1,2,3)
```

是一个数据源算子，这个数据源算子被`transform`编码成了`1`。

再比如，我们的代码

```java
.filter(r -> r.f0.equals("a"))
```

这是一个filter算子，被转换成了`3`。等等。转换成数字以后方便处理。


    
    
