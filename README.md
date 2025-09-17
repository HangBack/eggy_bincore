# 彬心

这是一个适用于蛋仔派对的序列化工具，可以通过预定义的schema去编解码序列数据。（其它平台Lua5.4可能依然适用，本项目并没有使用蛋仔派对专属的API）

# 为何使用

在蛋仔派对传统存档功能中，我们很难去存储一些自定义数据，序列化是一个很好的选择，本项目采用base94编码，再通过强大的schema系统，大大减少了存储的难度和空间。

# 如何使用

首先在你的项目中导入该程序

```lua
local Bincore = require "Bincore"
```

接着我们可以预定义一些schema数据。

最外层请务必按照这样的格式写
```lua
local schema = {
    type = "table",
    fields = {
        ...
    }
}
```

例如我们需要这样的数据
```lua
local data = {
    health = 100,
    inventory = {
        {
            id = 1,
            count = 10
        }
    }
}
```

我们就可以预定义这样的schema
```lua
local schema = {
    type = "table",
    fields = {
        { key = "health", type = "integer" },
        {
            key = "inventory",
            type = "array",
            element = {
                type = "table",
                fields = {
                    { key = "id", type = "integer" },
                    { key = "count", type = "integer" }
                }
            }
        }
    }
}
```
紧接着我们就可以存储我们的数据了

```lua
local encoded = Bincore.encode(data, schema)
```

这个数据会被转换成base94字符串，你可以将它按照每份长度64分成N份，从而存储到蛋仔派对的`字符串存档`中，其它平台请自己摸索。

需要使用的时候，从蛋仔派对的`字符串存档`按顺序获取后拼接在一起，例如拼接后的数据是`result`，那么我们可以通过下面的方式还原数据。

```lua
local decoded = Bincore.decode(result, schema)
```

除此之外`Bincore`还支持版本管理，内部直接嵌入的协议版本号，可通过修改版本号对比schema数据。可以查看[示例](./example.lua)以获得更多信息。

# 贡献

豆油汉堡