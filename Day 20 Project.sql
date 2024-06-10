use day_20_project;

select *
from worldlifexpectancy;
-- **Data Cleaing** 
-- 1. Handling Missing Data 
-- 1.1. Identifying Missing Values

Select *
from worldlifexpectancy
where Status = '';
-- Detected 8 Missing Values in `Status` Column
Select *
from worldlifexpectancy
where Lifeexpectancy = '' or Lifeexpectancy = 0;
-- Detected 2 Missing Values in `Lifeexpectancy` Column
Select *
from worldlifexpectancy
where GDP = '' or GDP = 0;
-- Detected 448 Missing Values (Equal 0 ) in `GDP` Column

-- 1.2. Strategy on handling missing values
	-- 1.2.1. Status
		-- Convert missing values into NULL values for the use of NULL functions
update worldlifexpectancy
set Status = NULL
where Status = '';

select *
from worldlifexpectancy
where Status is null;

		-- Strategy: Self Join the worldlifexpectancy table 2 times to create a comparison among the `Status` of the current year with the 'Status' of the previous year and the next year. Then use COALESCE function to update the null data with `Status` of the previous year, otherwise the next year.

select current_year.Country, current_year.Year, current_year.status, next_year.Country, next_year.Year, next_year.status, previous_year.Country, previous_year.Year, previous_year.status
from worldlifexpectancy current_year
	join worldlifexpectancy next_year on current_year.Country = next_year.Country and current_year.Year = next_year.year - 1
	join worldlifexpectancy previous_year on current_year.Country = previous_year.Country and current_year.Year = previous_year.year +1 ;

update worldlifexpectancy as current_year
	join worldlifexpectancy as next_year on current_year.Country = next_year.Country and current_year.Year = next_year.year - 1
	join worldlifexpectancy as previous_year on current_year.Country = previous_year.Country and current_year.Year = previous_year.year +1 
set current_year.status = coalesce(current_year.Status, previous_year.Status, next_year.Status) 
where current_year.Status is null;

	-- 1.2.2. Lifeexpectancy
		-- Convert missing values into NULL values for the use of NULL functions
update worldlifexpectancy
set Lifeexpectancy = NULL
where Lifeexpectancy = '' or Lifeexpectancy = 0;

select *
from worldlifexpectancy
where Lifeexpectancy is null;
		-- Strategy: Replace the Null Values in the Lifeexpetacncy Column with the average of the Lifeexpetacncy Value from the previous year and the following year of the same county
        
select Country, Year, Lifeexpectancy,
Lag(Lifeexpectancy) over (Order by country,Year) as prev_year, Lead(Lifeexpectancy) over (Order by country,Year) as next_year, (Lag(Lifeexpectancy) over (Order by country,Year) + Lead(Lifeexpectancy) over (Order by country,Year)) /2 as New_Lifeexpectancy
from worldlifexpectancy
order by country;

update worldlifexpectancy 
	join (select country, 
				 year,
                 (Lag(Lifeexpectancy) over (Order by country,Year) + Lead(Lifeexpectancy) over (Order by country,Year)) /2 as New_Lifeexpectancy
		  from worldlifexpectancy 
		  order by country) w2
	on worldlifexpectancy.country = w2.country  and worldlifexpectancy.year = w2.year 
set Lifeexpectancy = Round(New_Lifeexpectancy,2)
where Lifeexpectancy is null ;

	-- 1.2.3. GDP
			-- Strategy: Replace ' ' and '0' values in GPD with Null Values
update worldlifexpectancy
set GDP = NULL
where GDP = '' or Lifeexpectancy = 0;
	
-- 2. Data Consistancy
-- We can Spot some inconsistant values in the Lifeexpectancy Column
	-- Strategy: Convert The Lifeexpectancy into the same format of decimal(10,2)
ALTER TABLE worldlifexpectancy
MODIFY COLUMN Lifeexpectancy DECIMAL(10, 2);

-- 3. Removing Duplicates
-- Strategy: Delete duplicate rows using row_number function
delete from worldlifexpectancy
where row_id in (select row_id
				 from (select row_id,  Country, Year, row_number() over(partition by Country, Year) as row_num
					   from worldlifexpectancy) new_table
				 where row_num > 1);
                 
-- 4. Outlier Detection and Treatment
	-- 4.1. Identify Outliners 
	-- Strategy: Using z-score to find outliners where z-score > 2.576 (99% threshold)
select w1.Country, w1.Year, abs((w1.BMI - w2.mean)/nullif(w2.standard_dev,0)) as abs_z_score
from worldlifexpectancy w1 
	join
	(select Country, avg(BMI) as mean, stddev(BMI) as standard_dev
	from worldlifexpectancy 
	group by Country) w2 
    on w1.Country = w2.Country
where abs((w1.BMI - w2.mean)/nullif(w2.standard_dev,0)) > 2.576;

	-- 4.2. Deal with outliners
    -- Strategy: calculates the average BMI for each country in the previous and next year, then identifies outliers based on a threshold (in this case, values more than 2.576 standard deviations away from the mean). Then, updates the BMI values of the identified outliers with the rounded average BMI.
update worldlifexpectancy w
	join
		(select w4.Country, w4.Year,
			(select round(avg(w3.BMI),1)
			from worldlifexpectancy w3
			where w3.Country = w4.Country
			and w3.Year in (w4.Year + 1, w4.Year - 1)) as new_bmi 
		from worldlifexpectancy w4
		join
			(select w1.Country, w1.Year, abs((w1.BMI - w2.mean)/nullif(w2.standard_dev,0)) as abs_z_score
			from worldlifexpectancy w1 
				join
				(select Country, avg(BMI) as mean, stddev(BMI) as standard_dev
				from worldlifexpectancy 
				group by Country) w2 
			on w1.Country = w2.Country
			where abs((w1.BMI - w2.mean)/nullif(w2.standard_dev,0)) > 2.576) as outliners
		on w4.Country = outliners.Country and w4.Year = outliners.Year) as updates 
    on w.Country = updates.Country and w.Year = updates.Year
set w.BMI = updates.new_bmi;
    
-- **EDA**
-- 1. Basic Descriptive Statistics
	-- Mean, Minimum, Maximum of Lifeexpectancy in each country
select Country, avg(Lifeexpectancy) as mean, min(Lifeexpectancy) as min, max(Lifeexpectancy) as max
from worldlifexpectancy 
group by Country;
	-- Median of Lifeexpectancy in each country (Use row_num to identify the order of the Values and choosr the value in the middle)
select w.Country, w.Lifeexpectancy
from worldlifexpectancy w
	join
		(select Country, 
			   Lifeexpectancy,  
			   row_number() over(Partition by Country order by Lifeexpectancy) row_num, 
			   count(Lifeexpectancy) over(Partition by Country) total_count
		from worldlifexpectancy ) w1
	on w.Country = w1.Country and w.Lifeexpectancy = w1.Lifeexpectancy
where w1.row_num = floor((total_count + 1) / 2);

-- 2.Trend Analysis of a specific country
	-- Analyze the trend of life expectancy in each country by ordering the trend by years 
select Year, Lifeexpectancy
from worldlifexpectancy 
where Country = 'Viet Nam'
order by Year asc;
	-- Observation: Life expectancy in Vietnam rose consistantly over the course from 2007 to 2022 (73.40 to 76.00 in 16 years)
-- 3. Comparative Analysis
	-- Calculate and compare the average Life expectancy of 2 groups: 'Developing' and 'Developed' Countries in the lastest available year
select 
round(avg(case when `Status` = 'Developing' then Lifeexpectancy else null end),2) as avg_lifeex_developing,
round(avg(case when `Status` = 'Developed' then Lifeexpectancy else null end),2) as avg_lifeex_developed
from worldlifexpectancy
where Year = 2022;
	-- Observation: Up to the most recent available data, people living in Developed Countries tend to have significantly higher life expectancy (~11.02)
    
-- 4. Morality Analysis
 -- Calculate the correlation between 'Adult Morality' and 'Lifeexpectancy' for all Countries using Correlation Coefficient Function
 select 
	 (count(*)*(sum(AdultMortality * Lifeexpectancy)) - (Sum(AdultMortality) * sum(Lifeexpectancy)))/
	 sqrt(
		  (count(*)*(sum(AdultMortality*AdultMortality)) - sum(AdultMortality)*sum(AdultMortality))*
		  (count(*)*(sum(Lifeexpectancy*Lifeexpectancy)) - sum(Lifeexpectancy)*sum(Lifeexpectancy))
		  ) as Correlation_Coefficient
 from worldlifexpectancy;
 -- The result of 0.69 represents a relatively strong negative correlation between `AdultMortality` and `Lifeexpectancy`. This means that an increase in the value of `AdultMortality` will cause a relative decrease in the value of `Lifeexpectancy`.
 
 -- 5. Impact of GDP
	-- Find the average 'Lifeexpectancy' of countries group by their GDP (Low, Medium, High)
select 
	(Case when GDP < 1000 then 'Low'
			when GDP > 10000 then 'High'
			Else 'Medium'
		End) as GDP_Group,
	avg(Lifeexpectancy) as avg_lifeexpectancy
from worldlifexpectancy
Group by GDP_group
order by avg_lifeexpectancy, GDP_group;
-- Observation: We can clearly see that the higher the GDP of the group is, the higher Life Expectancy that group possess

-- 6. Disease Impact
	-- We will consider disease factors that affect the Lifeexpectancy across countries. Divide the Countries into Groups of 'High disease rate/incidents' and 'Low disease rate/incidents'. There are four disease in this analysis: Measles, Polio, Diphtheria and HIVAIDS.

	-- Measles

with cte_measles as
(select Country, Year, Lifeexpectancy, (case 
	when Measles >= (select avg(Measles) from worldlifexpectancy) then 'High Measles'
    when Measles < (select avg(Measles) from worldlifexpectancy) then 'Low Measles'
    end) as category
from worldlifexpectancy)
select 'High Measles', avg(Lifeexpectancy) as avg_lifex
from cte_measles
where category = 'High Measles'
union 
select 'Low Measles', avg(Lifeexpectancy) as avg_lifex
from cte_measles
where category = 'Low Measles';

	-- Polio
with cte_polio as
(select Country, Year, Lifeexpectancy, (case 
	when Polio >= (select avg(Polio) from worldlifexpectancy) then 'High Polio'
    when Polio < (select avg(Polio) from worldlifexpectancy) then 'Low Polio'
    end) as category
from worldlifexpectancy)
select 'High Polio', avg(Lifeexpectancy) as avg_lifex
from cte_polio
where category = 'High Polio'
union 
select 'Low Polio', avg(Lifeexpectancy) as avg_lifex
from cte_polio
where category = 'Low Polio';

	-- Diphtheria
with cte_diphtheria as
(select Country, Year, Lifeexpectancy, (case 
	when Diphtheria >= (select avg(Diphtheria) from worldlifexpectancy) then 'High Diphtheria'
    when Diphtheria < (select avg(Diphtheria) from worldlifexpectancy) then 'Low Diphtheria'
    end) as category
from worldlifexpectancy)
select 'High Diphtheria', avg(Lifeexpectancy) as avg_lifex
from cte_diphtheria
where category = 'High Diphtheria'
union 
select 'Low Diphtheria', avg(Lifeexpectancy) as avg_lifex
from cte_diphtheria
where category = 'Low Diphtheria';

	-- HIVAIDS
with cte_hivaids_rate as
(select Country, Year, Lifeexpectancy, (case 
	when HIVAIDS >= (select avg(HIVAIDS) from worldlifexpectancy) then 'High HIVAIDS'
    when HIVAIDS < (select avg(HIVAIDS) from worldlifexpectancy) then 'Low HIVAIDS'
    end) as category
from worldlifexpectancy)
select 'High HIVAIDS', avg(Lifeexpectancy) as avg_lifex
from cte_hivaids_rate
where category = 'High HIVAIDS'
union 
select 'Low HIVAIDS', avg(Lifeexpectancy) as avg_lifex
from cte_hivaids_rate
where category = 'Low HIVAIDS';

-- Observation: Measles and HIVAIDS appear to have negative correlation to Life expectancy, while Polio and Diphtheria appear to have positive correlation to Life expectancy

-- 7. Schooling and Health
	-- Analyze the correlation of schooling years of people 25 and older with the average Life expectancy by schooling logevity groups 
select 'Over-20-y Schooling' as Years_Schooling, avg(Lifeexpectancy) as avg_Lifex
from worldlifexpectancy
where schooling >=20
union 
select 'Over-15-y Schooling', avg(Lifeexpectancy)
from worldlifexpectancy
where schooling <20 and schooling >=15
union 
select 'Over-10-y Schooling', avg(Lifeexpectancy)
from worldlifexpectancy
where schooling <15 and schooling >=10
union 
select 'Under-10-y Schooling', avg(Lifeexpectancy)
from worldlifexpectancy
where schooling <10
order by avg_Lifex desc;

-- Observation: There is a positive correlation between higher levels of schooling and increased life expectancy. Generally, individuals with more years of education tend to have longer life expectancies.

-- 8. BMI Trends
	-- Find the average BMI trend over the years across all countries
select Year, avg(BMI) as avg_bmi
from worldlifexpectancy
group by Year
order by Year;
	-- Find the average BMI trend over the Years for a particular country
select Country, Year, avg(BMI) as avg_bmi
from worldlifexpectancy
where Country = 'Afghanistan'
group by Year, Country
order by Year;

-- Observation: The average BMI has been increasing over the years in most countries and over the world in general.

-- 9. Infant Morality
	-- Analyze the number of 'infantdeaths' and 'under-fivedeaths' in top 20 countries and with Highest Lifeexpectancy and top 20 with Lowest Lifeexpectancy

select Country, 
	   avg(Lifeexpectancy) as avg_lifex, 
       avg(infantdeaths) as avg_infant_deaths, 
       avg(`under-fivedeaths`) as avg_under5_deaths
from worldlifexpectancy
group by country
order by avg_lifex desc
limit 20;

select Country, 
	   avg(Lifeexpectancy) as avg_lifex, 
       avg(infantdeaths) as avg_infant_deaths, 
       avg(`under-fivedeaths`) as avg_under5_deaths
from worldlifexpectancy
group by country
order by avg_lifex asc
limit 20;

-- Observation: There is a significant different between the number of 'infantdeaths' and 'under-fivedeaths' in top 20 countries and with Highest Lifeexpectancy and top 20 with Lowest Lifeexpectancy. Countries with higher life expectancy shows less deaths among children.

-- 10. Rolling average of Adult Mortality 
	-- Analyze the Rolling average of Adult Mortality in each coutry and find the trends
select Country, Year, 
       round(avg(AdultMortality) over (partition by Country order by Year rows between 4 preceding and current row), 2) AS rolling_avg_adultmortality
from worldlifexpectancy
order by Country, Year;

-- Observation: In general, based on the trends observed, the rolling average adult mortality rates across the listed countries show a decreasing trend over time. The trends can vary for each country, with some experiencing fluctuations or periods of stability.

-- 11. Impact of Health Care Expenditure
	-- Calculate the correlation between 'Percentage Expenditure' and 'Lifeexpectancy' for all Countries using Correlation Coefficient Function
select
	 (count(*)*(sum(percentageexpenditure * Lifeexpectancy)) - (Sum(percentageexpenditure) * sum(Lifeexpectancy)))/
	 sqrt(
		  (count(*)*(sum(percentageexpenditure*percentageexpenditure)) - sum(percentageexpenditure)*sum(percentageexpenditure))*
		  (count(*)*(sum(Lifeexpectancy*Lifeexpectancy)) - sum(Lifeexpectancy)*sum(Lifeexpectancy))
		  ) as Correlation_Coefficient
 from worldlifexpectancy;
 
-- Observation: A correlation coefficient of 0.38 suggests a weak positive correlation between these two variables. There is a tendency for higher healthcare expenditure to be associated with slightly higher life expectancy, but the relationship is not very strong.

-- 12. BMI and Health Indicators
	-- Find the correlation between BMI and Health Indicators such as Lifeexpectancy and Adult Morality
	-- BMI and Lifeexpectancy
select
	 (count(*)*(sum(BMI * Lifeexpectancy)) - (Sum(BMI) * sum(Lifeexpectancy)))/
	 sqrt(
		  (count(*)*(sum(BMI*BMI)) - sum(BMI)*sum(BMI))*
		  (count(*)*(sum(Lifeexpectancy*Lifeexpectancy)) - sum(Lifeexpectancy)*sum(Lifeexpectancy))
		  ) as Correlation_Coefficient
from worldlifexpectancy;
-- Observation: A correlation coefficient of 0.67 suggests a moderate positive correlation between BMI and life expectancy. This indicates that there is a tendency for higher BMI to be associated with slightly higher life expectancy.
	-- BMI and Adult Mortality
select
	 (count(*)*(sum(BMI * AdultMortality)) - (Sum(BMI) * sum(AdultMortality)))/
	 sqrt(
		  (count(*)*(sum(BMI*BMI)) - sum(BMI)*sum(BMI))*
		  (count(*)*(sum(AdultMortality*AdultMortality)) - sum(AdultMortality)*sum(AdultMortality))
		  ) as Correlation_Coefficient
from worldlifexpectancy;
 
-- Observation: A correlation coefficient of -0.46 suggests a moderate negative correlation between BMI and adult mortality. This indicates that there is a tendency for higher BMI to be associated with slightly lower adult mortality rates.

-- 13. GDP and Health Outcomes
	-- Analyze how GDP influences Health Outcome such as 'Lifeexpectancy', 'AdultMortality' and 'infantdeaths'
select 
	(Case when GDP < 1000 then 'Low'
			when GDP > 10000 then 'High'
			Else 'Medium'
		End) as GDP_Group,
	avg(Lifeexpectancy) as avg_lifeexpectancy,
    avg(AdultMortality) as avg_adultmortality,
    avg(infantdeaths) as avg_infantdeaths
from worldlifexpectancy
Group by GDP_group
order by avg_lifeexpectancy, GDP_group;

-- Observation: Higher GDP is generally associated with higher life expectancy and lower rates of adult mortality and infant deaths. This implies that countries with higher economic development tend to have better health outcomes.

-- 14. Subgroup Analysis of Lifeexpectancy
	-- create a Continent table providing Continent information for each Country
create table Continent (
  Country varchar(60),
  Continent varchar(20));

Insert into Continent(Country,Continent) 
values
('Afghanistan','Asia'), ('Albania','Europe'), ('Algeria','Africa'), ('Angola','Africa'),
('Antigua and Barbuda','North America'), ('Argentina','South America'), ('Armenia','Europe'),
('Australia','Oceania'), ('Austria','Europe'), ('Azerbaijan','Europe'),
('Bahamas','North America'), ('Bahrain','Asia'), ('Bangladesh','Asia'),
('Barbados','North America'), ('Belarus','Europe'), ('Belgium','Europe'),
('Belize','North America'), ('Benin','Africa'), ('Bhutan','Asia'),
('Bolivia (Plurinational State of)','South America'), ('Bosnia and Herzegovina','Europe'),
('Botswana','Africa'), ('Brazil','South America'), ('Brunei Darussalam','Asia'),
('Bulgaria','Europe'), ('Burkina Faso','Africa'), ('Burundi','Africa'),
('Cabo Verde','Africa'), ('Cambodia','Asia'), ('Cameroon','Africa'),
('Canada','North America'), ('Central African Republic','Africa'), ('Chad','Africa'),
('Chile','South America'), ('China','Asia'), ('Colombia','South America'),
('Comoros','Africa'), ('Congo','Africa'), ('Costa Rica','North America'),
('Côte d''Ivoire','Africa'), ('Croatia','Europe'),('Cuba','North America'),
('Cyprus','Europe'),('Czechia','Europe'),('Democratic People''s Republic of Korea','Asia'),
('Democratic Republic of the Congo','Africa'),('Denmark','Europe'),('Djibouti','Africa'),
('Dominican Republic','North America'),('Ecuador','South America'),('Egypt','Africa'),
('El Salvador','North America'),('Equatorial Guinea','Africa'),('Eritrea','Africa'),
('Estonia','Europe'),('Ethiopia','Africa'),('Fiji','Oceania'),('Finland','Europe'),
('France','Europe'),('Gabon','Africa'),('Gambia','Africa'),('Georgia','Europe'),
('Germany','Europe'),('Ghana','Africa'),('Greece','Europe'),('Grenada','North America'),
('Guatemala','North America'),('Guinea','Africa'),('Guinea-Bissau','Africa'),
('Guyana','South America'),('Haiti','North America'),('Honduras','North America'),
('Hungary','Europe'),('Iceland','Europe'),('India','Asia'),('Indonesia','Asia'),
('Iran (Islamic Republic of)','Asia'),('Iraq','Asia'),('Ireland','Europe'),
('Israel','Asia'),('Italy','Europe'),('Jamaica','North America'),('Japan','Asia'),
('Jordan','Asia'),('Kazakhstan','Asia'),('Kenya','Africa'),('Kiribati','Oceania'),
('Kuwait','Asia'),('Kyrgyzstan','Asia'),('Lao People''s Democratic Republic','Asia'),
('Latvia','Europe'),('Lebanon','Asia'),('Lesotho','Africa'),('Liberia','Africa'),
('Libya','Africa'),('Lithuania','Europe'),('Luxembourg','Europe'),('Madagascar','Africa'),
('Malawi','Africa'),('Malaysia','Asia'),('Maldives','Asia'),('Mali','Africa'),
('Malta','Europe'),('Mauritania','Africa'),('Mauritius','Africa'),('Mexico','North America'),
('Micronesia (Federated States of)','Oceania'),('Mongolia','Asia'),('Montenegro','Europe'),
('Morocco','Africa'),('Mozambique','Africa'),('Myanmar','Asia'),('Namibia','Africa'),
('Nepal','Asia'),('Netherlands','Europe'),('New Zealand','Oceania'),('Nicaragua','North America'),
('Niger','Africa'),('Nigeria','Africa'),('Norway','Europe'),('Oman','Asia'),
('Pakistan','Asia'),('Panama','North America'),('Papua New Guinea','Oceania'),
('Paraguay','South America'),('Peru','South America'),('Philippines','Asia'),('Poland','Europe'),
('Portugal','Europe'),('Qatar','Asia'),('Republic of Korea','Asia'),('Republic of Moldova','Europe'),
('Romania','Europe'),('Russian Federation','Asia'),('Rwanda','Africa'),('Saint Lucia','North America'),
('Saint Vincent and the Grenadines','North America'),('Samoa','Oceania'),('Sao Tome and Principe','Africa'),
('Saudi Arabia','Asia'),('Senegal','Africa'),('Serbia','Europe'),('Seychelles','Africa'),
('Sierra Leone','Africa'),('Singapore','Asia'),('Slovakia','Europe'),('Slovenia','Europe'),
('Solomon Islands','Oceania'),('Somalia','Africa'),('South Africa','Africa'),('South Sudan','Africa'),
('Spain','Europe'),('Sri Lanka','Asia'),('Sudan','Africa'),('Suriname','South America'),
('Swaziland','Africa'),('Sweden','Europe'),('Switzerland','Europe'),('Syrian Arab Republic','Asia'),
('Tajikistan','Asia'),('Thailand','Asia'),('The former Yugoslav republic of Macedonia','Europe'),
('Timor-Leste','Asia'),('Togo','Africa'),('Tonga','Oceania'),('Trinidad and Tobago','North America'),
('Tunisia','Africa'),('Turkey','Europe'),('Turkmenistan','Asia'),('Uganda','Africa'),
('Ukraine','Europe'),('United Arab Emirates','Asia'),('United Kingdom of Great Britain and Northern Ireland','Europe'),
('United Republic of Tanzania','Africa'),('United States of America','North America'),('Uruguay','South America'),
('Uzbekistan','Asia'),('Vanuatu','Oceania'),('Venezuela (Bolivarian Republic of)','South America'),
('Viet Nam','Asia'),('Yemen','Asia'),('Zambia','Africa'),('Zimbabwe','Africa');

select c.Continent, avg(w.Lifeexpectancy) as avg_Lifex
from worldlifexpectancy w 
	join Continent c on w.Country = c.Country
group by c.Continent
order by avg_Lifex desc

-- Observation: There are significant variations in average life expectancy across different continents. Europe and North America tend to have higher life expectancies, while Asia, Oceania, and South America fall in the middle range. Africa consistently has the lowest average life expectancy.