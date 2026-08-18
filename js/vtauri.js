/**
 * vtauri.js — 前端 JS API
 * 对应 Tauri 的 @tauri-apps/api 包。提供 invoke / listen / emit 等接口，
 * 通过宿主（WebView2 / window.chrome.webview）与 V 后端通信。
 */
(function (global) {
  'use strict';

  // 生成唯一 id
  function genId() {
    return 'req_' + Date.now().toString(36) + '_' + Math.random().toString(36).slice(2, 10);
  }

  // 探测宿主 IPC 通道
  // 在 WebView2 下为 window.chrome.webview；跨平台时也可由 V 注入 window.__vtauriBridge。
  function getBridge() {
    if (global.chrome && global.chrome.webview) return global.chrome.webview;
    if (global.__vtauriBridge) return global.__vtauriBridge;
    return null;
  }

  // 发送 IPC 消息（POST 到后端）
  function post(raw) {
    var bridge = getBridge();
    if (!bridge) {
      throw new Error('vtauri: no IPC bridge available');
    }
    if (bridge.postMessage) {
      bridge.postMessage(raw);
    } else if (bridge.post) {
      bridge.post(raw);
    } else {
      throw new Error('vtauri: bridge does not support postMessage');
    }
  }

  // 挂起 Promise 表，用于 invoke 结果关联
  var pending = {};

  // 供后端调用：收到响应时 resolve 对应请求
  global.__vtauriOnResponse = function (resp) {
    var entry = pending[resp.id];
    if (!entry) return;
    delete pending[resp.id];
    if (resp.ok) {
      entry.resolve(resp.result);
    } else {
      entry.reject(new Error(resp.error || 'vtauri command failed'));
    }
  };

  // 供后端调用：收到事件广播时派发
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
    return new Promise(function (resolve, reject) {
      var id = genId();
      pending[id] = { resolve: resolve, reject: reject };
      post(JSON.stringify({
        id: id,
        command: command,
        args: JSON.stringify(args === undefined ? null : args)
      }));
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
    post(JSON.stringify({
      id: genId(),
      command: '__emit',
      args: JSON.stringify({ event: event, payload: payload })
    }));
  }

  var api = { invoke: invoke, listen: listen, emit: emit };
  global.__VTauri = api;
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = api;
  }
})(typeof window !== 'undefined' ? window : this);
