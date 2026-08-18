/**
 * vtauri.js — 前端 JS API
 * 对应 Tauri 的 @tauri-apps/api 包。提供 invoke / listen / emit 等接口。
 *
 * IPC 通道：在 Windows 上，vtauri 集成 webview/webview 库，后端通过
 * webview_bind 把 `__vtauriInvoke` 暴露为页面全局函数。调用它返回一个
 * Promise，最终由后端调用 webview_return 兑现为 IpcResponse。
 */
(function (global) {
  'use strict';

  // 生成唯一 id
  function genId() {
    return 'req_' + Date.now().toString(36) + '_' + Math.random().toString(36).slice(2, 10);
  }

  // 探测后端注入的 invoke 通道（webview/webview 库的 bind）
  function getInvoke() {
    if (typeof global.__vtauriInvoke === 'function') return global.__vtauriInvoke;
    return null;
  }

  // 事件监听表：后端 emit 事件时通过 __vtauriOnEvent 派发
  var listeners = {};
  global.__vtauriOnEvent = function (ev) {
    var list = listeners[ev.event] || [];
    list.forEach(function (fn) { try { fn(ev.payload); } catch (e) {} });
  };

  /**
   * invoke — 调用后端命令。
   * @param {string} command 命令名
   * @param {any} [args] 参数（会被 JSON 序列化）
   * @returns {Promise<any>}
   */
  function invoke(command, args) {
    var invokeFn = getInvoke();
    if (!invokeFn) {
      return Promise.reject(new Error('vtauri: __vtauriInvoke not available'));
    }
    var reqJson = JSON.stringify({
      id: genId(),
      command: command,
      args: JSON.stringify(args === undefined ? null : args)
    });
    // webview_bind 的 __vtauriInvoke 返回 Promise，兑现为解析后的 IpcResponse
    return invokeFn(reqJson).then(function (resp) {
      if (resp && resp.ok) {
        // result 是后端返回的 JSON 字符串（如 "Hello, ..."），解析后返回
        if (resp.result === undefined || resp.result === null || resp.result === '') {
          return null;
        }
        return JSON.parse(resp.result);
      }
      throw new Error((resp && resp.error) || 'vtauri command failed');
    });
  }

  /**
   * listen — 监听后端事件。
   * @param {string} event 事件名
   * @param {Function} handler (payload) => void
   * @returns {Function} 取消监听的函数
   */
  function listen(event, handler) {
    if (!listeners[event]) listeners[event] = [];
    listeners[event].push(handler);
    return function () {
      listeners[event] = (listeners[event] || []).filter(function (h) { return h !== handler; });
    };
  }

  /**
   * emit — 前端向后端发送一个事件（简单事件通知）。
   * @param {string} event
   * @param {any} payload
   */
  function emit(event, payload) {
    // 复用 __vtauriInvoke 通道，调用内置的 __emit 命令
    return invoke('__emit', { event: event, payload: payload });
  }

  var api = { invoke: invoke, listen: listen, emit: emit };
  global.__VTauri = api;
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = api;
  }
})(typeof window !== 'undefined' ? window : this);
