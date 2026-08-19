import React, { useState, useEffect } from 'react';

const COMMANDS = [
  {
    name: 'greet',
    label: '调用 greet',
    args: 'whiter',
    format: (r) => String(r),
  },
  {
    name: 'add',
    label: '调用 add (20 + 22)',
    args: { a: 20, b: 22 },
    format: (r) => `20 + 22 = ${r}`,
  },
  {
    name: 'info',
    label: '调用 info（JSON 对象）',
    args: undefined,
    format: (r) => JSON.stringify(r, null, 2),
  },
];

export default function App() {
  const [out, setOut] = useState('--');
  const [busy, setBusy] = useState(false);
  const [backendReady, setBackendReady] = useState(false);

  // 区分「浏览器打开」与「vtauri WebView2 内打开」：
  // 后者会由原生桥注入 window.__VTauri。
  useEffect(() => {
    const ready = typeof window.__VTauri !== 'undefined';
    setBackendReady(ready);
    if (!ready) setOut('未检测到 vtauri 运行时（请通过 vtauri 应用窗口打开本页）');
  }, []);

  async function run(cmd) {
    setBusy(true);
    setOut('调用中...');
    try {
      // invoke(command, args)：args 会被 JSON 序列化，返回值按 JSON 解析
      const result = await window.__VTauri.invoke(cmd.name, cmd.args);
      setOut(cmd.format(result));
    } catch (e) {
      setOut('错误: ' + e.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <main style={styles.wrap}>
      <div style={styles.card}>
        <h1 style={styles.h1}>vtauri × React</h1>
        <p style={styles.sub}>
          React 19 前端 · Vite 单文件构建 · 通过{' '}
          <code style={styles.code}>window.__VTauri.invoke</code> 调用 V 后端
        </p>

        <div style={backendReady ? styles.statusOk : styles.statusBad}>
          {backendReady ? '✓ vtauri 运行时已就绪' : '✗ vtauri 运行时未连接'}
        </div>

        <div style={styles.btns}>
          {COMMANDS.map((c) => (
            <button
              key={c.name}
              style={styles.btn}
              disabled={busy || !backendReady}
              onClick={() => run(c)}
            >
              {c.label}
            </button>
          ))}
        </div>

        <pre style={styles.out}>{out}</pre>
      </div>
    </main>
  );
}

const styles = {
  wrap: {
    minHeight: '100vh',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
    boxSizing: 'border-box',
  },
  card: {
    width: '100%',
    maxWidth: 520,
    background: '#fff',
    borderRadius: 14,
    padding: '32px 36px',
    boxShadow: '0 8px 24px rgba(0,0,0,0.08)',
  },
  h1: { fontSize: 22, marginBottom: 6 },
  sub: { color: '#666', fontSize: 13, lineHeight: 1.6, marginBottom: 18 },
  code: { background: '#eef', padding: '1px 5px', borderRadius: 4, fontSize: 12 },
  statusOk: {
    fontSize: 13,
    padding: '8px 12px',
    borderRadius: 8,
    marginBottom: 16,
    background: '#e8f7ee',
    color: '#177245',
  },
  statusBad: {
    fontSize: 13,
    padding: '8px 12px',
    borderRadius: 8,
    marginBottom: 16,
    background: '#fdeeee',
    color: '#b02a2a',
  },
  btns: { display: 'flex', gap: 10, flexWrap: 'wrap', marginBottom: 18 },
  btn: {
    padding: '9px 16px',
    border: 0,
    borderRadius: 8,
    background: '#61dafb',
    color: '#05262e',
    fontWeight: 600,
    fontSize: 14,
    cursor: 'pointer',
  },
  out: {
    minHeight: 90,
    padding: 14,
    borderRadius: 8,
    background: '#fafafa',
    border: '1px solid #eee',
    fontFamily: "ui-monospace, 'Cascadia Mono', Consolas, monospace",
    fontSize: 13,
    lineHeight: 1.6,
    whiteSpace: 'pre-wrap',
    wordBreak: 'break-all',
    color: '#177245',
    margin: 0,
  },
};
