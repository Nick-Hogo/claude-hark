import { LANGUAGES, useI18n } from '../i18n.jsx';

const TEMPLATES = [
  { id: 'ledger', nameKey: 'templates.ledger', descriptionKey: 'templates.ledgerDescription' },
  { id: 'river', nameKey: 'templates.river', descriptionKey: 'templates.riverDescription' },
  { id: 'kanban', nameKey: 'templates.kanban', descriptionKey: 'templates.kanbanDescription' },
];

export default function TemplateSwitcher({ value, onChange }) {
  const { language, setLanguage, t } = useI18n();
  return (
    <div className="mx-auto flex max-w-7xl flex-col gap-3 px-5 pt-6 md:px-8">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="text-xs font-bold uppercase tracking-[0.24em] text-stone-400">{t('templates.choose')}</div>
        <div className="flex flex-wrap gap-1.5 rounded-full bg-[#fff8e9]/80 p-1 ring-1 ring-[#e9dcc4]">
          {LANGUAGES.map((item) => (
            <button
              key={item.id}
              type="button"
              onClick={() => setLanguage(item.id)}
              className={`rounded-full px-3 py-1 text-xs font-bold transition ${language === item.id ? 'bg-stone-900 text-[#fff8e9]' : 'text-stone-500 hover:bg-white hover:text-stone-900'}`}
            >
              {item.label}
            </button>
          ))}
        </div>
      </div>
      <div className="flex flex-wrap gap-2">
        {TEMPLATES.map((template) => (
          <button
            key={template.id}
            type="button"
            onClick={() => onChange(template.id)}
            className={`rounded-full px-4 py-2 text-sm font-semibold transition ${
              value === template.id
                ? 'bg-stone-900 text-[#fff8e9] shadow-lg shadow-stone-900/10'
                : 'bg-[#fff8e9]/80 text-stone-500 ring-1 ring-[#e9dcc4] hover:bg-white hover:text-stone-900'
            }`}
            title={t(template.descriptionKey)}
          >
            {t(template.nameKey)}
          </button>
        ))}
      </div>
    </div>
  );
}
