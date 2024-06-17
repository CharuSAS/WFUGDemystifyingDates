
/*
SAS stores 
 - dates as integers
 - datetime & times as real numbers (to account for fractional seconds)

Fun facts
 - earliest date SAS can handle: Jan 1, 1582 (beginning of Gregorian calendar) 
 - latest date: around 20,000 (I forget exact date)
*/

/*1 The SAS date/time constants/literals*/
/*Tool - Data Step date time constants*/
data work.Literals;
  DateConstant='14jun2024'd;
  TimeConstant='13:15:00't; 
  DateTimeCons='14jun2024:21:31:00'dt;

  *The colon is a "starts-with" operator;
  format datec: worddate32. 
         timec: timeampm9.
		 datet: datetime19.; 
run;

/*2 Some basic SAS date functions;*/
/*Tool - today(), time(), Datetime()*/
data work.NowFunctions;
  Date=today(); *date(); *Today's date, based on system clock;
  Time=time();  *Current time, based on system clock;
  DateTime=datetime();
  format date worddate32. 
         time timeampm9.
		 datet: datetime19.; 
run;


/*3 Date functions whose name implies usage;*/
/*Tool - several date functions*/
data work.ABunchOFunctions;
  Today		  =	today();
  DayOfMonth  =	day(today);
  DayOfWeek	  =	weekday(today); *weekday(today)-1 to count Monday as 1st day;
  Month		  =	month(today);
  WeekOfYear  = week(today);
  Year		  =	year(today);
  Qtr		  =	qtr(today);

  format today worddate.;
run;


/*4 How does SAS store dates? As a number, 
the number of days since 1 January 1960. Viewing the column names, types 
& formats using proc contents is a good first step*/
proc contents data=sashelp.stocks;
run;

/*5 How can I manipulate dates if date is not stored in one column, */
proc contents data=sashelp.prdsale;
run;
proc print data=sashelp.prdsale(obs=100);
run;


/*6 transform the date by pulling together the columns so that */
/*date is in one column, making future calculations & manipulation easy*/
/*Tool - Input & Put Functions for Type Conversions, CAT function to concatenate*/
data prdsale;
set sashelp.prdsale;
charyear=put(year, 4.);
charmon=put(month,monname3.);
onedate=cat(charmon,charyear);
numdate=input(onedate,monyy7.);
format numdate monyy7.;
run;
proc contents;
run;
/*pre-work for later grouping*/
proc sort data=prdsale;
by numdate;
run;

/*7 Wells Fargo Specific Date Transformations*/
/*Tool - Input, MDY, DatePart Function*/
*Create some dummy data;
data d_calendar_dummy;
  infile cards dsd missover;
  input date_id 
  		date_value 	: datetime.
		YYYYMM
		YYYYQQ 
		QQ_YYYY 	: $7.
		Day
		Year
		Quarter
		Month 		: $12.
 		Month_Number
		Country 	: $2.;

  format date_value datetime.;
  cards;
20230712, 12jul2023:00:00:00, 202307, 2023003, Q3_2023, 12, 2023, 3, July,7, MX
20230824, 24aug2023:00:00:00, 202308, 2023003, Q3_2023, 24, 2023, 3, August,8, US
20231220, 20dec2023:00:00:00, 202312, 2023004, Q4_2023, 20, 2023, 4, December,12, CA
;
run;

*PUT vs INPUT Functions
 PUT always writes text 
	- PUT statement writes to log or a text file
	- PUT function writes to a variable during runtime
    - use a FORMAT with PUT of same data type as variable being referenced

 INPUT reads text and stores in a SAS variable as either text or numeric
    - INPUT statement used to provide read/import instructions in 
      a data step when reading text files
    - INPUT function used to convert text data to numeric when that data
      is already stored in a table (as opposed to being stored in a text file)
    - use an INFORMAT with INPUT of type of variable you want to create
;

data DateManipulations;
  *Using RETAIN only to move comparison columns next to each other;
  retain date_id Date_ID_Real date_value ExtractDate Month_Number day year MakeMDYDate;

  set work.d_calendar_dummy;

  *Convert "20230712", stored as numeric, to a SAS date;
  Date_ID_Real = input(put(date_id, 8.),yymmdd10.);

  *Create a SAS date from separate month, day, year columns;
  MakeMDYDate = mdy(Month_Number, day, year);

  *Extract a SAS date from a SAS datetime;
  ExtractDate = datepart(date_value);

  format Date_ID: Make: e: worddate.;
run;


/*8 Joining columns with dates that have columns with mismatched types*/
/*Tool - Input function to convert data*/

*Create dummy data for joining;
data work.sales;
  infile cards dsd missover;
  input date : date9. 
  		sales;
  format date date9.;
  cards;
12jul2023,456789
24aug2023,567890
20dec2023,654345
;
run;

*Join on dates in two tables, one of which is not
 a SAS date (convert date while joining);

proc sql inobs=1000000; 
  select s.date format=mmddyyd10.,
 		 d.country, 
		 s.sales format=dollar12.
    from work.d_calendar_dummy d
	  inner join
	     work.sales s
	on input(put(d.date_id, 8.),yymmdd10.)=s.date;
quit;



/*9 Determine the frequency with which an event occurs in time */
/*(e.g., how many products were sold in a given year)*/
/*TOOL - use SAS formats to influence grouping of dates in your SAS reports  */
/*without having to calculate new variables*/

proc freq data=prdsale order=freq;
tables product;
by numdate;
format numdate year4.;
run;


/*10.1 Find the time interval between consecutive dates */
/*TOOL - Lag function*/

/*The lag function is helpful for generating time-series data*/
data prdsale_interval;
    set prdsale;
    by numdate; /*by variable-calculations are done by date.*/
    if first.numdate then interval = .;/*initialize interval for the first date*/
    else interval = numdate - lag(numdate);/*diff between current & previous date */
run;

/* Display the result */
proc print data=prdsale_interval;
/*where interval <> .;*/
    var numdate interval ;
	format numdate date9.;
run;

/*10.2 Find the time interval between consecutive dates */
/*TOOL - SAS Date Interval Functions

 INTCK vs INTNX 
  
 INTCK 
   - returns a # (5 years, 7 weeks, etc.), by counting # of intervals between 2 dates
   - an interval might be days, weeks, months, half-months, years, quarters, etc.

 INTNX 
   - returns a date, by moving fwd/back to next date
   - think of "NX" as "next date," keeping in mind that "next" can be before or after.
  

 Use Examples
 INTCK: how many days/weeks/months/semi-months/10-day periods/years/etc.
        are between July 16, 1978 and June 5, 2004?
  		

 INTNX: Return a date that's 6 months from Sep 6, 2012. 
        Return a date that's the 1st of the month, 9 months from now 
        (or the middle or end of the month). 
;
 
/* INTCK's methods
   DISCRETE (default)
   Counts # times interval occurs between start & end. 
   Note: DISCRETE does not count # of complete intervals 
   between start & end, and does not begin with start 
   but at beginning of 1st interval after start. 

   Ex: Dec 31, 1999 - Jan 1, 2000 = one month, one year, etc., because
       a year/month "marker/hallmark" has been passed

   CONTINUOUS
   What I think of as more intuitive.
   Ex: Dec 31, 1999 - Jan 1, 2000 = zero months/years have passed
  
   In some situations DISCRETE can be the perfect solution, but in 
   general use, CONTINUOUS is probably more appropriate.
*/

/*INTCK vs INTNX*/

data work.IntCK_Examples;
  DayDiscrete		= intck('day','31dec2011'd,'01jan2012'd, 'd'); 
  DayContinuous		= intck('day','31dec2011'd,'01jan2012'd, 'c'); 

  WeekDiscrete		= intck('week','31dec2011'd,'01jan2012'd,'d'); 
  WeekContinuous	= intck('week','31dec2011'd,'01jan2012'd,'c'); 

  MonthDiscrete		= intck('month','31dec2011'd,'01jan2012'd,'d'); 
  MonthContinuous	= intck('month','31dec2011'd,'01jan2012'd,'c');
 
  YearDiscrete		= intck('year','31dec2011'd,'01jan2012'd,'d'); 
  YearContinuous	= intck('year','31dec2011'd,'01jan2012'd,'c'); 
run;

*Using INTCK with times;
data work.INTCK_Times;
  t1=50409.0280001163;
  t2=50434.4549999237;
  dif=intck('second',t1,t2); 
  format t: timeampm.;
run;


*Using INTCK with times, take 2
 Note that when I calculate minutes by dividing seconds 
 by 60 I get a more precise value than when I use the 
 'minute' interval specification;
data work.INTCK_Times;
  t1='2:09:34't;
  t2='2:34:27't;
  Dif_Seconds1=intck('second',t1,t2,'c'); 
  Dif_Minutes1=intck('second',t1,t2,'c')/60;
  Dif_Minutes2=intck('minute',t1,t2,'c'); 
  format t: timeampm.;
run;


*INTNX(interval,start,# increments, alignment);

data work.IntNX_Examples;
  Day 		= intnx('day',today(), 3);
  Weekday 	= intnx('weekday', today(), 3); *'weekday' doesn't count Sat/Sun;
  Month 	= intnx('month', today(), 6, 'b'); *'b','m','e','s';
  Qtr		= intnx('qtr', today(), 1, 's'); 
  Year		= intnx('year', today(), -6, 'e');

  format d: m: w: y: q: weekdate.;
run;


*Using YRDIF to calculate age;
data age;
  DOB = '12may1972'd;
  Age = int(yrdif(dob, today(),'age'));

  format dob weekdate.;
run;

/*11 Insert current date time in report titles*/
/*TOOL - Use macro variables*/

/* Macro variables to store the current date and time */
%let current_date = %sysfunc(date(), worddate.);
%let current_time = %sysfunc(time(), timeampm.);

/* Use the macro variables in the title statement */
title1 "Report generated on &current_date at &current_time";

/* Sample procedure to demonstrate the title */
proc print data=sashelp.class;
run;

/* Reset the title */
title;


/*12 Determine the current date and/or time on your computer’s system clock at*/
/*various points in your program’s execution.*/
/*TOOL - Date, time, datetime functions*/

data _null_;
/*Capture current date and time at the beginning of the program */  current_datetime1 = datetime();
    current_date1 = today();
    current_time1 = time();
    put "Start of the program - DateTime: " current_datetime1 datetime20.;
    put "Start of the program - Date: " current_date1 date9.;
    put "Start of the program - Time: " current_time1 time8.;

/* Simulate some processing with a delay */
    do i = 1 to 200000000;
        x = i**2;
    end;

/* Capture current date and time after some processing */
    current_datetime2 = datetime();
    current_date2 = today();
    current_time2 = time();
    put "After processing - DateTime: " current_datetime2 datetime20.;
    put "After processing - Date: " current_date2 date9.;
    put "After processing - Time: " current_time2 time8.;


/* Simulate more processing with a delay */
    do j = 1 to 200000000;
        y = j**2;
    end;

/* Capture current date and time at the end of the program */
    current_datetime3 = datetime();
    current_date3 = today();
    current_time3 = time();
	diff1=intck('dtseconds',current_time1, current_time2);
	diff2=intck('dtseconds',current_time2, current_time3);

    put "End of the program - DateTime: " current_datetime3 datetime20.;
    put "End of the program - Date: " current_date3 date9.;
    put "End of the program - Time: " current_time3 time8.;
	put "difference between start time & 1st processing time: " diff1 time8.;
	put "difference between 2nd processing time & end time: " diff2 time8.;

run;

