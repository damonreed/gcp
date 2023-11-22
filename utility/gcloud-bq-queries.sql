##
## gcloud bq queries
##

SELECT * 
  FROM `bigquery-public-data.london_bicycles.cycle_hire` 
  WHERE duration>=1200;

SELECT * 
  FROM `bigquery-public-data.london_bicycles.cycle_hire` 
  WHERE duration>=1200;

SELECT start_station_name 
  FROM `bigquery-public-data.london_bicycles.cycle_hire` 
  GROUP BY start_station_name;

SELECT start_station_name, COUNT(*) 
  FROM `bigquery-public-data.london_bicycles.cycle_hire` 
  GROUP BY start_station_name;

SELECT start_station_name, COUNT(*) AS num_starts 
  FROM `bigquery-public-data.london_bicycles.cycle_hire` 
  GROUP BY start_station_name;

SELECT start_station_name, COUNT(*) AS num 
  FROM `bigquery-public-data.london_bicycles.cycle_hire` 
  GROUP BY start_station_name 
  ORDER BY start_station_name;

SELECT start_station_name, COUNT(*) AS num 
  FROM `bigquery-public-data.london_bicycles.cycle_hire` 
  GROUP BY start_station_name 
  ORDER BY num;

SELECT start_station_name, COUNT(*) AS num 
  FROM `bigquery-public-data.london_bicycles.cycle_hire` 
  GROUP BY start_station_name 
  ORDER BY num DESC;

SELECT end_station_name, COUNT(*) AS num 
  FROM `bigquery-public-data.london_bicycles.cycle_hire` 
  GROUP BY end_station_name 
  ORDER BY num DESC;