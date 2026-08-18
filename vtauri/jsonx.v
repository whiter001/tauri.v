// jsonx.v — json 便捷封装
// 统一使用 V 0.5.x 标准 json 模块，减少调用点重复代码。
module vtauri

import json

// encode 将任意可序列化值编码为 JSON 字符串。
pub fn encode[T](val T) string {
	return json.encode(val)
}

// decode 从 JSON 字符串解码为目标类型 T。
// 基础类型（int、string）走特化分支；struct/map/array 等复合类型交给 json.decode。
pub fn decode[T](data string) !T {
	$if T is int {
		return parse_int(data)
	} $else $if T is string {
		return unquote_string(data)
	} $else {
		return json.decode(T, data)
	}
}

// parse_int 将字符串解析为 int，非法输入返回错误。
fn parse_int(data string) !int {
	if data == '' {
		return error('invalid int: empty string')
	}
	for c in data {
		if c < `0` || c > `9` {
			return error('invalid int: $data')
		}
	}
	return data.int()
}

// unquote_string 将 JSON 字符串字面量（带包围引号）还原为原始字符串，并处理常见转义。
fn unquote_string(data string) string {
	if data.len >= 2 && data[0] == `"` && data[data.len - 1] == `"` {
		return data[1..data.len - 1].replace('\\"', '"').replace('\\n', '\n').replace('\\\\', '\\')
	}
	return data
}
