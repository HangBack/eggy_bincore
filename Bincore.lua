---@class Bincore
local Bincore = {}

-- 类型标识符
local TYPE_NIL = 0
local TYPE_BOOLEAN = 1
local TYPE_INTEGER = 2
local TYPE_STRING = 3
local TYPE_TABLE = 4
local TYPE_ARRAY = 5

-- 当前协议版本
Bincore.PROTOCOL_VERSION = 1

-- 二进制序列化
local function serialize_value(value, buffer, field_schema)
    local value_type = field_schema.type
    if value == nil then
        value_type = "nil"
    end

    if value_type == "nil" then
        table.insert(buffer, string.char(TYPE_NIL))
    elseif value_type == "boolean" then
        if value == nil then
            error("布尔值不能为 nil")
        end
        table.insert(buffer, string.char(TYPE_BOOLEAN))
        table.insert(buffer, value and "\1" or "\0")
    elseif value_type == "integer" then
        if value == nil or type(value) ~= "number" then
            error("整数值不能为 nil 或非数字类型")
        end
        table.insert(buffer, string.char(TYPE_INTEGER))
        -- 使用小端序存储8字节整数
        local bytes = {}
        for i = 1, 8 do
            bytes[i] = string.char(value & 0xFF)
            value = value >> 8
        end
        table.insert(buffer, table.concat(bytes))
    elseif value_type == "string" then
        if value == nil or type(value) ~= "string" then
            error("字符串值不能为 nil 或非字符串类型")
        end
        table.insert(buffer, string.char(TYPE_STRING))
        local len = #value
        -- 存储字符串长度（4字节）
        for i = 1, 4 do
            table.insert(buffer, string.char(len & 0xFF))
            len = len >> 8
        end
        table.insert(buffer, value)
    elseif value_type == "table" then
        if value == nil or type(value) ~= "table" then
            error("表值不能为 nil 或非表类型")
        end
        -- 普通表处理
        table.insert(buffer, string.char(TYPE_TABLE))
        -- 存储表元素数量
        local count = #field_schema.fields
        for i = 1, 4 do
            table.insert(buffer, string.char(count & 0xFF))
            count = count >> 8
        end
        -- 按照schema顺序序列化键值对
        for _, field in ipairs(field_schema.fields) do
            serialize_value(value[field.key], buffer, field)
        end
    elseif value_type == "array" then
        if value == nil or type(value) ~= "table" then
            error("数组值不能为 nil 或非表类型")
        end
        table.insert(buffer, string.char(TYPE_ARRAY))
        -- 序列化数组结构
        local array_schema = field_schema and field_schema.element or {}
        local count = #value
        -- 存储数组长度
        for i = 1, 4 do
            table.insert(buffer, string.char(count & 0xFF))
            count = count >> 8
        end
        -- 序列化数组元素
        for i = 1, #value do
            serialize_value(value[i], buffer, array_schema)
        end
    else
        error("不支持的数据类型: " .. value_type .. " (value: " .. tostring(value) .. ")")
    end
end

-- 二进制反序列化
local function deserialize_value(data, pos, field_schema, target_version)
    -- 检查数据完整性
    if not data or #data == 0 then
        error("数据为空或损坏")
    end
    if pos > #data then
        error("数据读取越界: 位置 " .. tostring(pos) .. " 超出数据长度 " .. tostring(#data))
    end

    local type_id = string.byte(data, pos)
    pos = pos + 1
    
    if type_id == TYPE_NIL then
        return nil, pos
    elseif type_id == TYPE_BOOLEAN then
        local value = string.byte(data, pos) == 1
        return value, pos + 1
    elseif type_id == TYPE_INTEGER then
        local value = 0
        for i = 0, 7 do
            value = value | (string.byte(data, pos + i) << (i * 8))
        end
        return value, pos + 8
    elseif type_id == TYPE_STRING then
        local len = 0
        for i = 0, 3 do
            len = len | (string.byte(data, pos + i) << (i * 8))
        end
        pos = pos + 4
        local value = string.sub(data, pos, pos + len - 1)
        return value, pos + len
    elseif type_id == TYPE_TABLE then
        local count = 0
        for i = 0, 3 do
            count = count | (string.byte(data, pos + i) << (i * 8))
        end
        pos = pos + 4
        
        local table_value = {}
        
        -- 处理不同版本的字段差异
        if field_schema and field_schema.fields then
            for i = 1, count do
                local field_schema_item = field_schema.fields[i]
                if field_schema_item then
                    local value, new_pos = deserialize_value(data, pos, field_schema_item, target_version)
                    table_value[field_schema_item.key] = value
                    pos = new_pos
                else
                    -- 跳过未知字段
                    local _, new_pos = deserialize_value(data, pos, {type = "nil"}, target_version)
                    pos = new_pos
                end
            end
        else
            -- 没有schema信息，跳过所有字段
            for i = 1, count do
                local _, new_pos = deserialize_value(data, pos, {type = "nil"}, target_version)
                pos = new_pos
            end
        end
        
        return table_value, pos
    elseif type_id == TYPE_ARRAY then
        local count = 0
        for i = 0, 3 do
            count = count | (string.byte(data, pos + i) << (i * 8))
        end
        pos = pos + 4
        
        local array_schema = field_schema and field_schema.element or {}
        local array_value = {}
        
        for i = 1, count do
            local value, new_pos = deserialize_value(data, pos, array_schema, target_version)
            pos = new_pos
            array_value[i] = value
        end
        
        return array_value, pos
    else
        error("未知的类型标识符: " .. type_id)
    end
end

-- Base94编码
local function base94_encode(data)
    local result = {}
    local value = 0
    local bits = 0

    for i = 1, #data do
        value = value | (string.byte(data, i) << bits)
        bits = bits + 8

        while bits >= 6 do
            local index = value & 63
            if index < 94 then
                table.insert(result, string.char(33 + index))
            else
                table.insert(result, string.char(33 + (index % 94)))
            end
            value = value >> 6
            bits = bits - 6
        end
    end

    if bits > 0 then
        table.insert(result, string.char(33 + (value & ((1 << bits) - 1))))
    end

    return table.concat(result)
end

-- Base94解码
local function base94_decode(encoded)
    local result = {}
    local value = 0
    local bits = 0

    for i = 1, #encoded do
        local char_value = string.byte(encoded, i) - 33
        value = value | (char_value << bits)
        bits = bits + 6

        while bits >= 8 do
            table.insert(result, string.char(value & 255))
            value = value >> 8
            bits = bits - 8
        end
    end

    return table.concat(result)
end

-- 公共接口
function Bincore.encode(data, schema)
    local buffer = {}
    
    -- 写入协议版本（4字节）
    local version = Bincore.PROTOCOL_VERSION
    for i = 1, 4 do
        table.insert(buffer, string.char(version & 0xFF))
        version = version >> 8
    end
    
    -- 序列化数据
    serialize_value(data, buffer, schema)
    local binary_data = table.concat(buffer)
    return base94_encode(binary_data)
end

function Bincore.decode(encoded_string, schema)
    local binary_data = base94_decode(encoded_string)
    
    -- 读取协议版本
    local version = 0
    for i = 0, 3 do
        version = version | (string.byte(binary_data, i+1) << (i * 8))
    end
    
    local pos = 5  -- 前4字节是版本号
    local value, new_pos = deserialize_value(binary_data, pos, schema, version)
    
    return value
end

return Bincore