// 这个入口文件负责挂载 React dashboard 并注入国际化上下文。
// 应用入口：将根组件挂载到 DOM，外层包裹国际化上下文提供者
import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App.jsx';
import { I18nProvider } from './i18n.jsx';
import './styles.css';

createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <I18nProvider>
      <App />
    </I18nProvider>
  </React.StrictMode>,
);
