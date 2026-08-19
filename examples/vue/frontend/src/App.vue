<script setup>
import { ref, onMounted } from 'vue';

const out = ref('--');
const busy = ref(false);
const backendReady = ref(false);

// 区分「浏览器打开」与「vtauri WebView2 内打开」：
// 后者会由原生桥注入 window.__VTauri。
onMounted(() => {
  backendReady.value = typeof window.__VTauri !== 'undefined';
  if (!backendReady.value) {
    out.value = '未检测到 vtauri 运行时（请通过 vtauri 应用窗口打开本页）';
  }
});

async function run(command, label) {
  busy.value = true;
  out.value = '调用中...';
  try {
    // invoke(command, args)：args 会被 JSON 序列化，返回值按 JSON 解析
    const result = await window.__VTauri.invoke(command, label.args);
    out.value = label.format ? label.format(result) : JSON.stringify(result, null, 2);
  } catch (e) {
    out.value = '错误: ' + e.message;
  } finally {
    busy.value = false;
  }
}

const commands = [
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
</script>

<template>
  <main class="wrap">
    <div class="card">
      <h1>vtauri × Vue 3</h1>
      <p class="sub">
        Vue 3 前端 · Vite 单文件构建 · 通过 <code>window.__VTauri.invoke</code> 调用 V 后端
      </p>

      <div class="status" :class="backendReady ? 'ok' : 'bad'">
        {{ backendReady ? '✓ vtauri 运行时已就绪' : '✗ vtauri 运行时未连接' }}
      </div>

      <div class="btns">
        <button
          v-for="c in commands"
          :key="c.name"
          :disabled="busy || !backendReady"
          @click="run(c.name, c)"
        >
          {{ c.label }}
        </button>
      </div>

      <pre class="out">{{ out }}</pre>
    </div>
  </main>
</template>

<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body {
  font-family: system-ui, 'Segoe UI', sans-serif;
  background: #f5f5f7;
  color: #1a1a1a;
}
.wrap {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
}
.card {
  width: 100%;
  max-width: 520px;
  background: #fff;
  border-radius: 14px;
  padding: 32px 36px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.08);
}
h1 { font-size: 22px; margin-bottom: 6px; }
.sub { color: #666; font-size: 13px; line-height: 1.6; margin-bottom: 18px; }
.sub code { background: #eef; padding: 1px 5px; border-radius: 4px; font-size: 12px; }
.status {
  font-size: 13px;
  padding: 8px 12px;
  border-radius: 8px;
  margin-bottom: 16px;
}
.status.ok { background: #e8f7ee; color: #177245; }
.status.bad { background: #fdeeee; color: #b02a2a; }
.btns { display: flex; gap: 10px; flex-wrap: wrap; margin-bottom: 18px; }
.btns button {
  padding: 9px 16px;
  border: 0;
  border-radius: 8px;
  background: #42b883;
  color: #fff;
  font-size: 14px;
  cursor: pointer;
}
.btns button:hover:not(:disabled) { opacity: 0.88; }
.btns button:disabled { opacity: 0.45; cursor: not-allowed; }
.out {
  min-height: 90px;
  padding: 14px;
  border-radius: 8px;
  background: #fafafa;
  border: 1px solid #eee;
  font-family: ui-monospace, 'Cascadia Mono', Consolas, monospace;
  font-size: 13px;
  line-height: 1.6;
  white-space: pre-wrap;
  word-break: break-all;
  color: #177245;
}
</style>
