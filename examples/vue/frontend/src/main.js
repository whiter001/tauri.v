// main.js — vtauri vue 示例前端入口
//
// 1. 先导入 vtauri.js（UMD 脚本，副作用是挂载 window.__VTauri 提供 invoke/listen/emit），
//    这样组件里可以直接使用 window.__VTauri.invoke(...) 调用 V 后端命令。
// 2. 再启动 Vue 应用。
import './vtauri.js';

import { createApp } from 'vue';
import App from './App.vue';

createApp(App).mount('#app');
