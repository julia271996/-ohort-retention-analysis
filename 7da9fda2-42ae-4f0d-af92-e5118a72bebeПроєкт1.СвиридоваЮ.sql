--Крок 1.Очищення та трансформація дат для користувачів і подій---
with users_parsed as(
select user_id,
       promo_signup_flag,
       case 
       	when replace(replace(split_part(trim(signup_datetime),' ',1), '.','-'),'/','-') like '%-__'
       then to_date(replace(replace(split_part(trim(signup_datetime),' ',1), '.','-'),'/','-'),'DD-MM-YY')
       	else to_date(replace(replace(split_part(trim(signup_datetime),' ',1), '.','-'),'/','-'),'DD-MM-YYYY')
       end::date as signup_date
       from project.cohort_users_raw cur 
),
--Крок 2.Очищення даних про активність(події)
events_parsed as (
select user_id,
       event_type,
case
 	when replace(replace(split_part(trim(event_datetime),' ',1), '.','-'),'/','-') like '%-__'
       then to_date(replace(replace(split_part(trim(event_datetime),' ',1), '.','-'),'/','-'),'DD-MM-YY')
       	else to_date(replace(replace(split_part(trim(event_datetime),' ',1), '.','-'),'/','-'),'DD-MM-YYYY')
 end::timestamp as event_ts
       	from project.cohort_events_raw 
),
--Крок 3 Об`єднання таблиць (Join)та розрахунок метрик стажу 
user_activity as(
 select 
 u.user_id,
 u.promo_signup_flag,
 date_trunc('month',u.signup_date)::date as cohort_month,
 date_trunc('month',e.event_ts)::date as activity_month,
 e.event_type,
 e.event_ts,
 (extract(year from e.event_ts)-extract(year from u.signup_date))*12 +
 (extract(month from e.event_ts)-extract(month from u.signup_date)) as month_offset
 from users_parsed u
 join events_parsed e on u.user_id=e.user_id
 where u.signup_date is not null
 and e.event_ts is not null
 and e.event_type is not null
 and e.event_type<>'test_event'
 --Крок 4 Фінальна агрегація даних.Будуємо таблицю з кількістю унікальних користувачів для кожної когорти та місяця стажу--
 )
 select promo_signup_flag,
        cohort_month,
        month_offset,
        count(distinct user_id)as users_total
 from user_activity
 --Обмежуємо період спостереження за активністю
 where activity_month between '2025-01-01' and '2025-06-01'
 group by promo_signup_flag,
          cohort_month,
          month_offset
 --Сортування для зручності побудови когортної таблиці
 order by promo_signup_flag,
          cohort_month,
          month_offset
 
 