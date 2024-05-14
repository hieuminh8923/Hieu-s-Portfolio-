/*
Covid 19 Data Exploration (Data time range: 1/1/2022 - 4/4/2024)

Skills used: Joins, CTE's, Temp Tables, Windows Functions, Aggregate Functions, Creating Views, Converting Data Types

*/

-- Go over the data on the Project
Select *
From [Project 1]..CovidDeaths$
Where continent is not null 
order by 3,4

Select *
From [Project 1]..CovidVaccinations$
Where continent is not null 
order by 3,4


-- 1. Select Data for Exploration (Location, Date, Total cases, New cases, Total Deaths, Population)

Select Location, date, total_cases, new_cases, total_deaths, population
From [Project 1]..CovidDeaths$
Where continent is not null 
order by 1,2


-- 2. Looking at the Total Cases, Total Deaths, and DeathPercentage  in specific country

Select Location, date, total_cases,total_deaths, (total_deaths/total_cases)*100 as DeathPercentage
From [Project 1]..CovidDeaths$
Where location like '%vietnam%'
and continent is not null 
order by 1,2


-- 3. Looking at Total Cases and Population, and Show the percentage of population that is infected with Covid-19 in specific country

Select Location, date, Population, total_cases,  (total_cases/population)*100 as PercentPopulationInfected
From [Project 1]..CovidDeaths$
Where location like '%vietnam%'
order by 1,2


-- 4. Looking at Countries with the highest percentage of population that is infected with Covid-19

Select Location, Population, MAX(total_cases) as HighestInfectionCount,  Max((total_cases/population))*100 as PercentPopulationInfected
From [Project 1]..CovidDeaths$
Group by Location, Population
order by PercentPopulationInfected desc


-- 5. Looking at Countries with the highest death count because of Covid-19

Select Location, MAX(cast(Total_deaths as int)) as TotalDeathCount
From [Project 1]..CovidDeaths$
Where continent is not null 
Group by Location
order by TotalDeathCount desc

-- 6. Looking at Continents with the highest death count because of Covid-19

Select continent, MAX(cast(Total_deaths as int)) as TotalDeathCount
From [Project 1]..CovidDeaths$
Where continent is not null 
Group by continent
order by TotalDeathCount desc

-- 7. Looking at Total cases, Total death and Death percentage on the globe. 

Select  SUM(new_cases) as total_cases, SUM(cast(new_deaths as int)) as total_deaths, SUM(cast(new_deaths as int))/SUM(New_Cases)*100 as DeathPercentage
From [Project 1]..CovidDeaths$
where continent is not null 
order by 1,2

-- 8. Shows Percentage of Population that has recieved at least one Covid Vaccine
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CAST(vac.new_vaccinations as bigint)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
From [Project 1]..CovidDeaths$ dea
Join [Project 1]..CovidVaccinations$ vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null 
order by 2,3

-- 9. Using CTE to perform Calculation of 'Rolling Percentage of vacinated people over population' on Partition By in previous query

With PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingPeopleVaccinated)
as
(
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CAST(vac.new_vaccinations as bigint)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
From [Project 1]..CovidDeaths$ dea
Join [Project 1]..CovidVaccinations$ vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null 
)
Select *, (RollingPeopleVaccinated/Population)*100 as RollingVaccinnatedPercentage
From PopvsVac

-- 10 Using Temp Table to perform Calculation of 'Rolling Percentage of vacinated people over population' on Partition By in previous query

DROP Table if exists #PercentPopulationVaccinated
Create Table #PercentPopulationVaccinated
(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
New_vaccinations numeric,
RollingPeopleVaccinated numeric
)

Insert into #PercentPopulationVaccinated
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CAST(vac.new_vaccinations as bigint)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
From [Project 1]..CovidDeaths$ dea
Join [Project 1]..CovidVaccinations$ vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null 

Select *, (RollingPeopleVaccinated/Population)*100 as RollingVaccinatedPercentage
From #PercentPopulationVaccinated

-- 11. Creating View to store data for later visualizations

Create View PercentPopulationVaccinated as
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CAST(vac.new_vaccinations as bigint)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
From [Project 1]..CovidDeaths$ dea
Join [Project 1]..CovidVaccinations$ vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null 
