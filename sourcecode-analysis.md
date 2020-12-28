# flink 1.12源码分析

我们找一个最简单的flink程序word count来分析源码。

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


    
    
