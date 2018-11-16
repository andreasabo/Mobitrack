# This script create database and tables for mobitrack.

import mysql.connector

db = mysql.connector.connect (
		host="localhost",
		user="root", #yourusername
		passwd="password" #yourpw
	)


mycursor = db.cursor()

# Create database if it doesn't exist
mycursor.execute("CREATE DATABASE IF NOT EXISTS mobitrack")
mycursor.execute("USE mobitrack")

# Create the wearing session table if it doesn't exist
mycursor.execute("CREATE TABLE IF NOT EXISTS wearing_session (" +
				 "SessionID VARCHAR(16), " +
				 "PatientID VARCHAR(255), " +
				 "Location VARCHAR(20), " + 
				 "TimeStamp DATE )")
				 
# Create the exercise period table if it doesn't exist
mycursor.execute("CREATE TABLE IF NOT EXISTS exercise_period (" +
				 "PeriodID VARCHAR(16), " +
				 "SessionID VARCHAR(16), " +
				 "Duration VARCHAR(255), " +
				 "Repetitions VARCHAR(20), " + 
				 "TimeStamp DATE )")