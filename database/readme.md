# This folder is for managing codes relevent to database of Mobitrack

The following documentation contains information regards to design choices made related to database & required packages.

1. Choice of Database: 

For Mobitrack, MySQL is used due to multiple reasons
	-> Offers default schema reinforcement: We want the data to have all the fields completed when we insert the data into the database
	-> Open source & widely supported (big community): Offers good community support, easily adaptable to different developing environment
	-> high availability (every request receives a response about whether it succeeded or not) & high consistency (all database has latest successful transaction updated) due to the quality of rdbms (relational database management system)
	
2. Things to Do:
- System Requirements:
	- MySQL 
	- MySQL-python
	