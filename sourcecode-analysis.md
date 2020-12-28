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
    
也就是说先将StreamGraph转换成JobGraph，然后再从JobGraph转换成ExecutionGraph。    

而`getStreamGraph`就是用来获取`StreamGraph`数据结构的。

当我们点击`getStreamGraph`时，代码会跳转到当前文件的`1975`行，而第`1976`行是：

```java
return getStreamGraph(jobName, true);
```

看的出来，还要继续点击，继续点击来到了同文件的`1990`行，以下是函数体

```java
1990	public StreamGraph getStreamGraph(String jobName, boolean clearTransformations) {
1991		StreamGraph streamGraph = getStreamGraphGenerator().setJobName(jobName).generate();
1992		if (clearTransformations) {
1993			this.transformations.clear();
1994		}
1995		return streamGraph;
1996	}
```

第1991行代码，产生了一个StreamGraph，而第1995行代码，返回了这个StreamGraph。
    
    
    
    
