// main.jsx — vtauri react 示例前端入口
//
// 1. 先导入 vtauri.js（UMD 脚本，副作用是挂载 window.__VTauri 提供 invoke/listen/emit）。
// 2. 再渲染 React 应用。
import './vtauri.js';

import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App.jsx';

createRoot(document.getElementById('root')).render(<App />);
