# Report Format Contract

The financial analysis skill outputs a Telegram-compatible Markdown report in Russian.

## Report Structure

```markdown
# 📊 Финансовый отчёт за {месяц} {год}

## 💰 Итоги

| Показатель | Сумма | Изменение |
|------------|-------|-----------|
| Доходы     | X руб. | +Y% ↑    |
| Расходы    | X руб. | -Y% ↓    |
| Переводы   | X руб. |           |
| Баланс     | X руб. | +Y% ↑    |

## 📋 Расходы по категориям

| Категория | Сумма | Доля | vs прошлый месяц |
|-----------|-------|------|-------------------|
| {cat1}    | X руб. | Y% | +Z% ↑            |
| {cat2}    | X руб. | Y% | -Z% ↓            |
| ...       |       |      |                   |

## 🔍 Аномалии

- ⚠️ {Описание аномальной транзакции с суммой и датой}

## 📈 Тренды (при наличии 3+ месяцев истории)

| Категория | Тренд | Последние N месяцев |
|-----------|-------|---------------------|
| {cat1}    | ↑ Рост | X → Y → Z руб.    |
| {cat2}    | ↓ Снижение | X → Y → Z руб. |
| {cat3}    | → Стабильно | X → Y → Z руб. |

## 🔗 Кросс-корреляции (при наличии 3+ месяцев истории)

- {cat1} и {cat2} растут вместе последние N месяцев
- {cat3} растёт, когда {cat4} снижается

## 📊 Бюджет vs Факт (если настроены бюджеты)

| Категория | Бюджет | Факт | Использовано |
|-----------|--------|------|--------------|
| {cat1}    | X руб. | Y руб. | Z% ⚠️     |

## 💡 Рекомендации

1. {Конкретная рекомендация с цифрами}
2. {Конкретная рекомендация с цифрами}
3. {Конкретная рекомендация с цифрами}
```

## Rules

- Sections with no data are omitted entirely (no "N/A" sections).
- Trends and correlations sections appear only when 3+ months of history exist.
- Budget section appears only when ZenMoney budgets are configured.
- Arrows: ↑ for increase, ↓ for decrease, → for stable (±5% tolerance).
- Anomaly threshold: single transaction > 2x the category's monthly average.
- Recommendations must reference specific categories and amounts.
- Multi-currency: if transactions exist in multiple currencies, each currency gets its own "Итоги" and "Расходы по категориям" sub-sections.
