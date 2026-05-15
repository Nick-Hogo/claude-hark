import React from 'react';

export const LANGUAGES = [
  { id: 'zh', label: '中文' },
  { id: 'en', label: 'EN' },
  { id: 'ja', label: '日本語' },
];

const DICTIONARY = {
  zh: {
    common: {
      unknown: '未知',
      idle: '空闲',
      noActivity: '无活动',
      noSummary: '暂无摘要。',
      resolving: '解析中...',
      never: '从未',
      state: '状态',
      updated: '更新',
      refresh: '刷新',
      autoRefreshOn: '自动刷新 开',
      autoRefreshOff: '自动刷新 关',
      events: '事件',
      sessions: '会话',
      event: '事件',
      tool: '工具',
      target: '目标',
      source: '来源',
      recorded: '记录时间',
    },
    events: {
      'user-prompt-submit': '用户输入',
      'pre-tool-use': '预执行',
      'post-tool-use': '执行后',
      'post-tool-use-failure': '执行失败',
      permission: '权限',
      elicitation: '选择',
      stop: '待回顾',
      'stop-failure': '异常结束',
      idle: '空闲',
    },
    templates: {
      choose: '选择 dashboard 草稿',
      ledger: '账本',
      river: '河流',
      kanban: '任务板',
      ledgerDescription: '白底日志账本，信息清晰，边框最少',
      riverDescription: '柔和流线，把事件当作会话河流',
      kanbanDescription: '按状态分栏，更像任务看板',
    },
    empty: {
      title: '还没有会话遥测',
      body: '触发 Claude Code 的 Edit、Write、Bash 权限请求，或用户选择事件。Claude-Hark 会把 hook 历史追加到 state.json，并自动刷新这里的 dashboard。',
    },
    board: {
      eyebrow: 'RPG 任务日志',
      title: '掌控你的 Agent 冒险。',
      subtitle: '用于监督 Claude Code 会话的本地任务板：待响应的关卡、正在推进的工作，以及可重新打开的历史轨迹。',
      calendarTitle: 'AI 活动',
      keystones: '关键节点',
      keystonesBody: '选择要接管的 Agent 前，先查看最近值得记住的关卡。',
      noKeystones: '还没有权限或选择关键节点。',
      marker: '标记',
      sessionIndex: 'Session 索引',
      show: '显示',
      hide: '隐藏',
      noCards: '这个列表里暂无 session 卡片。',
      soundOn: '提示音 开',
      soundOff: '提示音 关',
      testSound: '试听',
      columns: {
        quests: ['任务面板', '等待你选择或授权'],
        active: ['进行中', 'Claude 正在分析或执行'],
        archive: ['待回顾', '本轮已完成，等待下一步'],
      },
    },
    detail: {
      back: '← 返回任务板',
      eyebrow: '任务时间线',
      gate: '关卡',
      gateBody: '在 Claude Code 中批准或拒绝当前权限请求。',
      trace: '轨迹',
      traceBody: '展开旧步骤，恢复 Agent 为什么走到这里。',
      command: '指挥',
      commandBody: '回到任务板，选择下一个要控制的 session。',
      logTitle: '冒险日志',
      logSubtitle: '{count} 条 hook 步骤 · 最新在前',
      gateCheck: '关卡检查',
      questStep: '任务步骤',
      aiJudgment: 'AI 判断',
      purpose: '目的',
      summary: '摘要',
      details: '细节',
      suggestion: '建议',
      review: '审阅',
      renderedBody: '通知正文',
      aiInput: 'AI 输入',
      attributes: '属性',
      hookDerived: '来自 hook 历史',
      sessionName: 'Session 名称',
      description: '描述',
      stats: {
        events: '事件',
        runtime: '运行时间',
        queries: '查询',
        commands: '命令',
        tokens: 'Tokens',
        cost: '开销',
        notCaptured: '未捕获',
        notEnoughData: '数据不足',
      },
    },
  },
  en: {
    common: {
      unknown: 'unknown',
      idle: 'idle',
      noActivity: 'no activity',
      noSummary: 'No summary.',
      resolving: 'resolving...',
      never: 'never',
      state: 'state',
      updated: 'updated',
      refresh: 'refresh',
      autoRefreshOn: 'auto refresh on',
      autoRefreshOff: 'auto refresh off',
      events: 'events',
      sessions: 'sessions',
      event: 'event',
      tool: 'tool',
      target: 'target',
      source: 'source',
      recorded: 'recorded',
    },
    events: {
      'user-prompt-submit': 'user input',
      'pre-tool-use': 'preflight',
      'post-tool-use': 'after tool',
      'post-tool-use-failure': 'tool failed',
      permission: 'permission',
      elicitation: 'choice',
      stop: 'review',
      'stop-failure': 'failed stop',
      idle: 'idle',
    },
    templates: {
      choose: 'choose dashboard draft',
      ledger: 'Ledger',
      river: 'River',
      kanban: 'Kanban',
      ledgerDescription: 'Clean logbook view with minimal borders',
      riverDescription: 'Soft flow view that treats events as session rivers',
      kanbanDescription: 'Status columns shaped like a task board',
    },
    empty: {
      title: 'No session telemetry yet',
      body: 'Trigger a Claude Code Edit, Write, Bash permission request, or elicitation event. Claude-Hark will append hook history to state.json and this dashboard will refresh automatically.',
    },
    board: {
      eyebrow: 'RPG quest journal',
      title: 'Command your agent adventure.',
      subtitle: 'A local quest board for supervising Claude Code sessions: gates to answer, work in motion, and completed traces you can reopen.',
      calendarTitle: 'AI activity',
      keystones: 'Keystones',
      keystonesBody: 'Recent gates worth remembering before choosing which agent to control.',
      noKeystones: 'No permission or elicitation keystones yet.',
      marker: 'marker',
      sessionIndex: 'Session index',
      show: 'show',
      hide: 'hide',
      noCards: 'No session cards in this lane.',
      soundOn: 'sound on',
      soundOff: 'sound off',
      testSound: 'test',
      columns: {
        quests: ['Task Board', 'waiting for your choice or approval'],
        active: ['In Progress', 'Claude is analyzing or executing'],
        archive: ['Review', 'turn completed, waiting for next step'],
      },
    },
    detail: {
      back: '← Back to quest board',
      eyebrow: 'quest timeline',
      gate: 'Gate',
      gateBody: 'Approve or reject the current permission request in Claude Code.',
      trace: 'Trace',
      traceBody: 'Expand older steps to recover why the agent moved here.',
      command: 'Command',
      commandBody: 'Return to the board and choose the next session to control.',
      logTitle: 'Adventure log',
      logSubtitle: '{count} recorded hook steps · newest first',
      gateCheck: 'Gate check',
      questStep: 'Quest step',
      aiJudgment: 'AI judgment',
      purpose: 'purpose',
      summary: 'summary',
      details: 'details',
      suggestion: 'suggestion',
      review: 'review',
      renderedBody: 'notification body',
      aiInput: 'AI input',
      attributes: 'Attributes',
      hookDerived: 'hook-derived',
      sessionName: 'Session name',
      description: 'Description',
      stats: {
        events: 'events',
        runtime: 'runtime',
        queries: 'queries',
        commands: 'commands',
        tokens: 'tokens',
        cost: 'cost',
        notCaptured: 'not captured',
        notEnoughData: 'not enough data',
      },
    },
  },
  ja: {
    common: {
      unknown: '不明',
      idle: '待機中',
      noActivity: '活動なし',
      noSummary: '概要はありません。',
      resolving: '解決中...',
      never: '未更新',
      state: '状態',
      updated: '更新',
      refresh: '更新',
      autoRefreshOn: '自動更新 オン',
      autoRefreshOff: '自動更新 オフ',
      events: 'イベント',
      sessions: 'セッション',
      event: 'イベント',
      tool: 'ツール',
      target: '対象',
      source: 'ソース',
      recorded: '記録時刻',
    },
    events: {
      'user-prompt-submit': 'ユーザー入力',
      'pre-tool-use': '事前実行',
      'post-tool-use': '実行後',
      'post-tool-use-failure': '実行失敗',
      permission: '権限',
      elicitation: '選択',
      stop: 'レビュー待ち',
      'stop-failure': '異常終了',
      idle: '待機中',
    },
    templates: {
      choose: 'dashboard 草案を選択',
      ledger: '台帳',
      river: 'リバー',
      kanban: 'カンバン',
      ledgerDescription: '境界線を抑えた読みやすいログ台帳',
      riverDescription: 'イベントをセッションの流れとして見せる柔らかい表示',
      kanbanDescription: '状態別のタスクボード表示',
    },
    empty: {
      title: 'セッション telemetry はまだありません',
      body: 'Claude Code の Edit、Write、Bash 権限リクエスト、または入力選択イベントを発生させてください。Claude-Hark は hook 履歴を state.json に追記し、この dashboard を自動更新します。',
    },
    board: {
      eyebrow: 'RPG クエスト記録',
      title: 'Agent の冒険を指揮する。',
      subtitle: 'Claude Code セッションを監督するローカルクエストボードです。応答待ちのゲート、進行中の作業、再確認できる完了済みの軌跡を扱います。',
      calendarTitle: 'AI 活動',
      keystones: 'キーストーン',
      keystonesBody: '操作する Agent を選ぶ前に、最近の重要なゲートを確認します。',
      noKeystones: '権限または選択のキーストーンはまだありません。',
      marker: 'マーカー',
      sessionIndex: 'Session 索引',
      show: '表示',
      hide: '隠す',
      noCards: 'このレーンに session カードはありません。',
      soundOn: '通知音 オン',
      soundOff: '通知音 オフ',
      testSound: '試聴',
      columns: {
        quests: ['タスクボード', '選択または承認待ち'],
        active: ['進行中', 'Claude が分析または実行中'],
        archive: ['レビュー待ち', 'このターンは完了し、次の指示待ち'],
      },
    },
    detail: {
      back: '← クエスト板へ戻る',
      eyebrow: 'クエストタイムライン',
      gate: 'ゲート',
      gateBody: 'Claude Code で現在の権限リクエストを承認または拒否します。',
      trace: '軌跡',
      traceBody: '古いステップを展開して、Agent がここに至った理由を確認します。',
      command: '指揮',
      commandBody: 'ボードに戻り、次に制御する session を選びます。',
      logTitle: '冒険ログ',
      logSubtitle: '{count} 件の hook ステップ · 新しい順',
      gateCheck: 'ゲート確認',
      questStep: 'クエストステップ',
      aiJudgment: 'AI 判断',
      purpose: '目的',
      summary: '概要',
      details: '詳細',
      suggestion: '提案',
      review: 'レビュー',
      renderedBody: '通知本文',
      aiInput: 'AI 入力',
      attributes: '属性',
      hookDerived: 'hook 履歴由来',
      sessionName: 'Session 名',
      description: '説明',
      stats: {
        events: 'イベント',
        runtime: '実行時間',
        queries: '検索',
        commands: 'コマンド',
        tokens: 'Tokens',
        cost: 'コスト',
        notCaptured: '未取得',
        notEnoughData: 'データ不足',
      },
    },
  },
};

const I18nContext = React.createContext(null);

function initialLanguage() {
  const stored = window.localStorage.getItem('claude-hark-language');
  if (DICTIONARY[stored]) return stored;
  const browser = window.navigator.language.toLowerCase();
  if (browser.startsWith('ja')) return 'ja';
  if (browser.startsWith('zh')) return 'zh';
  return 'en';
}

function lookup(language, key) {
  return key.split('.').reduce((value, part) => value?.[part], DICTIONARY[language]);
}

function interpolate(value, params) {
  if (!params) return value;
  return Object.entries(params).reduce((text, [key, replacement]) => text.replaceAll(`{${key}}`, replacement), value);
}

export function I18nProvider({ children }) {
  const [language, setLanguageState] = React.useState(initialLanguage);
  const setLanguage = (nextLanguage) => {
    if (!DICTIONARY[nextLanguage]) return;
    window.localStorage.setItem('claude-hark-language', nextLanguage);
    setLanguageState(nextLanguage);
  };
  const t = React.useCallback((key, params) => {
    const value = lookup(language, key) ?? lookup('en', key) ?? key;
    return typeof value === 'string' ? interpolate(value, params) : value;
  }, [language]);

  return <I18nContext.Provider value={{ language, setLanguage, t }}>{children}</I18nContext.Provider>;
}

export function useI18n() {
  const context = React.useContext(I18nContext);
  if (!context) throw new Error('useI18n must be used inside I18nProvider');
  return context;
}
