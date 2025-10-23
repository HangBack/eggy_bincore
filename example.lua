local Bincore = require "Library.Bincore"

local schema = {
    type = "table",
    fields = {
        {
            key = "vault",
            type = "table",
            fields = {
                { key = "coin", type = "integer" },
                { key = "crystal", type = "integer" },
                { key = "diamond", type = "integer" }
            }
        },
        {
            key = "inventory",
            type = "array",
            element = {
                type = "table",
                fields = {
                    { key = "code", type = "string" },
                    {
                        key = "data",
                        type = "table",
                        fields = {
                            { key = "lasting", type = "integer" }
                        }
                    }
                }
            }
        },
        {
            key = "equipment",
            type = "array",
            element = {
                type = "table",
                fields = {
                    { key = "code", type = "string" },
                    {
                        key = "data",
                        type = "table",
                        fields = {
                            { key = "lasting", type = "integer" }
                        }
                    }
                }
            }
        },
        {
            key = "is_over",
            type = "integer"
        }
    }
}

local data = {
    inventory = {
        {
            code = "hello_world"
        }
    },
    is_over = 10
}

--一代版本
Bincore.PROTOCOL_VERSION = 1
local encoded = Bincore.encode(data, schema)
local decoded = Bincore.decode(encoded, schema)
print(decoded)

--二代版本
Bincore.PROTOCOL_VERSION = 2
--[[
二代新增is_complete字段

注意，以后更新字段只能在后面插入新的字段。

因为是按照字段顺序进行编解码的，如果你需要在中间插入新的字段就不得不自
己实现迁移函数，使用旧版本的schema先解码然后再使用新版本的schema编码。
]]
table.insert(schema.fields, {
    key = "is_complete", type = "integer"
})
---数据新增hello_eggy物品
table.insert(decoded.inventory, {
    code = "hello_eggy"
})
encoded = Bincore.encode(decoded, schema)
decoded = Bincore.decode(encoded, schema)
--上一代版本的数据还未新增is_complete字段，但是缺损值能被版本监控到
print(decoded)