// jsonx.v — json2 便捷封装
// 统一使用 V 0.5.x 的 json2 模块，减少调用点重复代码。
module vtauri

import json2
import json2.decoder2

// encode 将任意可序列化值编码为 JSON 字符串。
pub fn encode[T](val T) string {
	return json2.encode(val, json2.EncoderOptions{})
}

// decode 从 JSON 字符串解码为目标类型 T。
pub fn decode[T](data string) !T {
	return decoder2.decode[T](data)
}
