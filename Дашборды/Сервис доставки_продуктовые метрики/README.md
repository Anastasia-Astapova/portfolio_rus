# Расчёт ключевых бизнес-метрик сервиса доставки еды «Всё.из.кафе» (Саранск)

Учебный проект по аналитике данных и визуализации метрик с использованием **Yandex DataLens** и **SQL**.

---

## Описание проекта и бизнес-контекст

В рамках данного учебного проекта перед аналитиком стояла задача исследовать ключевые бизнес-показатели сервиса доставки еды **«Всё.из.кафе»** по городу Саранску за период с мая по июнь 2021 года. 

Цель проекта — подготовить SQL-запросы, построить интерактивные визуализации в Yandex DataLens, собрать итоговый дашборд и сформулировать практические выводы в аналитической записке для старшего аналитика.

---

## Стек технологий и инструменты

* **BI-платформа:** Yandex DataLens (построение QL-чартов и дашбордов)
* **Язык запросов:** SQL (агрегации, оконные функции, работа с датами и когортами)

---

## Структура дашборда и ключевые метрики

Дашборд разработан для наглядного отслеживания динамики показателей, выявления аномалий и анализа поведения пользователей. Набор визуализаций включает:

1. **DAU (Daily Active Users):** Количество уникальных активных пользователей (совершивших заказ) по дням.
2. **CR (Conversion Rate):** Доля пользователей, успешно оформивших заказ.
3. **Средний чек:** Динамика средней суммы покупки на пользователя.
4. **Retention Rate (RR):** Коэффициент удержания (возврата) пользователей в течение 1 недели после регистрации (совокупный и в разбивке по месяцам).
5. **Топ-3 ресторанов:** Рейтинг заведений по LTV (накопительному доходу за период).
6. **Топ-5 блюд:** Рейтинг блюд по LTV с детальной информацией.

---

## Пример реализации QL-запроса (Retention Rate)

Для расчёта недельного коэффициента удержания пользователей использовался следующий SQL-запрос, объединяющий данные о первых посещениях и ежедневной активности:

```sql
-- Рассчитываем новых пользователей по дате первого посещения продукта
WITH new_users AS
  (SELECT DISTINCT first_date,
                   user_id
   FROM rest_analytics.analytics_events AS events
   JOIN rest_analytics.cities cities ON events.city_id = cities.city_id
   WHERE first_date BETWEEN '2021-05-01' AND '2021-06-24'
     AND city_name = 'Саранск'),
-- Рассчитываем активных пользователей по дате события
active_users AS
  (SELECT DISTINCT log_date,
                   user_id
   FROM rest_analytics.analytics_events AS events
   JOIN rest_analytics.cities cities ON events.city_id = cities.city_id
   WHERE log_date BETWEEN '2021-05-01' AND '2021-06-30'
     AND city_name = 'Саранск'),
-- Соединяем таблицы с новыми и активными пользователями
daily_retention AS
  (SELECT n.user_id,
          first_date,
          log_date::date - first_date::date AS day_since_install
   FROM new_users AS n
   JOIN active_users AS a ON n.user_id = a.user_id
   AND log_date >= first_date)
SELECT DISTINCT CAST(DATE_TRUNC('month', first_date) AS date) AS "Месяц",
       day_since_install,
       COUNT(DISTINCT user_id) AS retained_users,
       ROUND((1.0 * COUNT(DISTINCT user_id) / MAX(COUNT(DISTINCT user_id)) OVER (PARTITION BY CAST(DATE_TRUNC('month', first_date) AS date)
ORDER BY day_since_install))::numeric, 2) AS retention_rate
FROM daily_retention
WHERE day_since_install < 8
GROUP BY "Месяц", day_since_install
ORDER BY "Месяц", day_since_install;
```
___
Структура репозитория:

```text
.
├── Dashboard_demo.mp4          # Видеозапись работы и интерактивных возможностей дашборда
├── Аналитическая записка.md    # Подробные выводы по метрикам и рекомендации для старшего аналитика
└── README.md                   # Описание проекта