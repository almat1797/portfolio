# список клиентов с непрерывной историей за год, то есть каждый месяц на регулярной основе без пропусков за указанный годовой период, 
# средний чек за период с 01.06.2015 по 01.06.2016, средняя сумма покупок за месяц, количество всех операций по клиенту за период;информацию в разрезе месяцев:
WITH months AS (
    SELECT DATE_FORMAT(date_new, '%Y-%m') AS ym, ID_client
    FROM Trancastions
    WHERE date_new >= '2015-06-01' AND date_new < '2016-06-01'
    GROUP BY ID_client, DATE_FORMAT(date_new, '%Y-%m')
),
client_month_counts AS (
    SELECT ID_client, COUNT(DISTINCT ym) AS active_months
    FROM months
    GROUP BY ID_client
)
SELECT ID_client
FROM client_month_counts
WHERE active_months = 12;


# Средняя сумма чека в месяц
SELECT
    DATE_FORMAT(t.date_new, '%Y-%m') AS month,
    ROUND(AVG(t.Sum_payment), 2) AS avg_check
FROM Trancastions t
GROUP BY DATE_FORMAT(t.date_new, '%Y-%m')
ORDER BY month;

# Среднее количество операций в месяц
SELECT
    AVG(operations_count) AS avg_operations_per_month
FROM (
    SELECT
        DATE_FORMAT(t.date_new, '%Y-%m') AS month,
        COUNT(t.Id_check) AS operations_count
    FROM Trancastions t
    GROUP BY DATE_FORMAT(t.date_new, '%Y-%m')
) AS monthly_operations;


# Среднее количество клиентов, которые совершали операции
SELECT
    AVG(clients_count) AS avg_clients_per_month
FROM (
    SELECT
        DATE_FORMAT(t.date_new, '%Y-%m') AS month,
        COUNT(DISTINCT t.ID_client) AS clients_count
    FROM Trancastions t
    GROUP BY DATE_FORMAT(t.date_new, '%Y-%m')
) AS monthly_clients;

# Доля от общего количества операций за год и доля в месяц от общей суммы операций
SELECT
    DATE_FORMAT(t.date_new, '%Y-%m') AS month,
    COUNT(t.Id_check) AS operations_count,
    SUM(t.Sum_payment) AS total_sum,
    ROUND(COUNT(t.Id_check) / (SELECT COUNT(*) FROM Trancastions) * 100, 2) AS operations_share_percent,
    ROUND(SUM(t.Sum_payment) / (SELECT SUM(Sum_payment) FROM Trancastions) * 100, 2) AS sum_share_percent
FROM Trancastions t
GROUP BY DATE_FORMAT(t.date_new, '%Y-%m')
ORDER BY month;

# % соотношение M/F/NA в каждом месяце с их долей затрат
SELECT
    DATE_FORMAT(t.date_new, '%Y-%m') AS month,
    c.Gender,
    COUNT(t.Id_check) AS operations_count,
    SUM(t.Sum_payment) AS total_sum,
    ROUND(COUNT(t.Id_check) / SUM(COUNT(t.Id_check)) OVER (PARTITION BY DATE_FORMAT(t.date_new, '%Y-%m')) * 100, 2) AS gender_operations_percent,
    ROUND(SUM(t.Sum_payment) / SUM(SUM(t.Sum_payment)) OVER (PARTITION BY DATE_FORMAT(t.date_new, '%Y-%m')) * 100, 2) AS gender_sum_percent
FROM Trancastions t
LEFT JOIN Сustomers c ON t.ID_client = c.Id_client
GROUP BY DATE_FORMAT(t.date_new, '%Y-%m'), c.Gender
ORDER BY month, c.Gender;



SELECT
    CASE
        WHEN c.Age IS NULL THEN 'NA'
        WHEN c.Age BETWEEN 0 AND 9 THEN '0-9'
        WHEN c.Age BETWEEN 10 AND 19 THEN '10-19'
        WHEN c.Age BETWEEN 20 AND 29 THEN '20-29'
        WHEN c.Age BETWEEN 30 AND 39 THEN '30-39'
        WHEN c.Age BETWEEN 40 AND 49 THEN '40-49'
        WHEN c.Age BETWEEN 50 AND 59 THEN '50-59'
        WHEN c.Age BETWEEN 60 AND 69 THEN '60-69'
        ELSE '70+'
    END AS age_group,
    COUNT(t.Id_check) AS total_operations,
    SUM(t.Sum_payment) AS total_sum
FROM Trancastions t
LEFT JOIN Сustomers c ON t.ID_client = c.Id_client
GROUP BY age_group
ORDER BY age_group;


# возрастные группы клиентов с шагом 10 лет и отдельно клиентов, у которых нет данной информации,
# с параметрами сумма и количество операций за весь период, и поквартально - средние показатели и %.
WITH age_groups AS (
    SELECT
        t.ID_client,
        t.Id_check,
        t.Sum_payment,
        t.date_new,
        CASE
            WHEN c.Age IS NULL THEN 'NA'
            WHEN c.Age BETWEEN 0 AND 9 THEN '0-9'
            WHEN c.Age BETWEEN 10 AND 19 THEN '10-19'
            WHEN c.Age BETWEEN 20 AND 29 THEN '20-29'
            WHEN c.Age BETWEEN 30 AND 39 THEN '30-39'
            WHEN c.Age BETWEEN 40 AND 49 THEN '40-49'
            WHEN c.Age BETWEEN 50 AND 59 THEN '50-59'
            WHEN c.Age BETWEEN 60 AND 69 THEN '60-69'
            ELSE '70+'
        END AS age_group
    FROM Trancastions t
    LEFT JOIN Сustomers c ON t.ID_client = c.Id_client
),
quarterly AS (
    SELECT
        YEAR(date_new) AS year,
        QUARTER(date_new) AS quarter,
        age_group,
        COUNT(Id_check) AS operations_count,
        SUM(Sum_payment) AS total_sum
    FROM age_groups
    GROUP BY YEAR(date_new), QUARTER(date_new), age_group
),
quarterly_percent AS (
    SELECT
        year,
        quarter,
        age_group,
        operations_count,
        total_sum,
        ROUND(operations_count / SUM(operations_count) OVER (PARTITION BY year, quarter) * 100, 2) AS operations_percent,
        ROUND(total_sum / SUM(total_sum) OVER (PARTITION BY year, quarter) * 100, 2) AS sum_percent,
        ROUND(total_sum / operations_count, 2) AS avg_check_per_operation
    FROM quarterly
),
total AS (
    SELECT
        age_group,
        COUNT(Id_check) AS total_operations,
        SUM(Sum_payment) AS total_sum,
        ROUND(SUM(Sum_payment) / COUNT(Id_check), 2) AS avg_check_per_operation
    FROM age_groups
    GROUP BY age_group
)
SELECT
    t.age_group,
    t.total_operations,
    t.total_sum,
    t.avg_check_per_operation,
    q.year,
    q.quarter,
    q.operations_count AS quarter_operations,
    q.total_sum AS quarter_sum,
    q.operations_percent,
    q.sum_percent,
    q.avg_check_per_operation AS quarter_avg_check
FROM total t
LEFT JOIN quarterly_percent q ON t.age_group = q.age_group
ORDER BY t.age_group, q.year, q.quarter;
