// jsonx.v — json 便捷封装
// 统一使用 V 0.5.x 标准 json 模块，减少调用点重复代码。
module vtauri

import json

// encode 将任意可序列化值编码为 JSON 字符串。
pub fn encode[T](val T) string {
	return json.encode(val)
}

// decode 从 JSON 字符串解码为目标类型 T。
pub fn decode[T](data string) !T {
	return json.decode[T](data)
}
