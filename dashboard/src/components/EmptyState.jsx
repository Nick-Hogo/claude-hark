import { useI18n } from '../i18n.jsx';

export default function EmptyState({ statePath }) {
  const { t } = useI18n();
  return (
    <section className="mt-8 rounded-[2rem] border border-dashed border-slate-700 bg-slate-950/55 p-10 text-center shadow-2xl shadow-black/30 backdrop-blur">
      <div className="mx-auto grid h-16 w-16 place-items-center rounded-2xl border border-cyan-300/30 bg-cyan-300/10 text-2xl font-black text-cyan-200">∅</div>
      <h2 className="mt-5 text-2xl font-black tracking-[-0.04em] text-white">{t('empty.title')}</h2>
      <p className="mx-auto mt-3 max-w-2xl text-sm leading-6 text-slate-400">
        {t('empty.body')}
      </p>
      <div className="mx-auto mt-5 max-w-3xl rounded-2xl border border-slate-800 bg-black/40 p-4 text-left font-mono text-xs text-slate-400">
        {t('common.state')}: <span className="text-slate-200">{statePath || t('common.resolving')}</span>
      </div>
    </section>
  );
}
