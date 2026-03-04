# Money Agent — Справочник

## BestChange — Ключевые валюты

| Валюта | ID |
|--------|----|
| USDT TRC20 | 10 |
| СБП | 21 |
| Сбербанк RUB | 42 |
| BTC | 93 |
| ETH | 139 |
| Сбербанк QR | 229 |

Для других валют: `search_currencies("название или код")`.

### Как читать курс

- `rate` — сколько from-валюты нужно за 1 to-валюту (технический, обратный)
- `price` — сколько to-валюты ты получаешь за 1 from-валюту (понятный пользователю)

Пример: USDT→Сбер, `price=95.3` → 1 USDT = 95.3 RUB

### Типовые запросы

```
# Лучший курс USDT → рубли для 1000 USDT
get_best_rate(from_currency_id=10, to_currency_id=42, amount=1000)

# Сравнить BTC→RUB и USDT→RUB
get_rates_batch(pairs=["93-42", "10-42"])

# Все доступные направления из USDT
get_presences(from_currency_id=10, to_currency_id=0)
```

---

## ZenMoney — Периоды и формат

Формат дат: `YYYY-MM-DD` (строка) или Unix timestamp (число).

```
# Текущий месяц
get_transactions(from="2026-03-01", to="2026-03-31")

# Прошлый месяц
get_transactions(from="2026-02-01", to="2026-02-28")
```

Счета и их ID — получить актуальный список: `get_accounts()`
