# import the SQL module
import pymonetdb

# set up a connection. arguments below are the defaults
connection = pymonetdb.connect(username="monetdb", password="monetdb", hostname="localhost", database="fixture")

# create a cursor
cursor = connection.cursor()

# increase the rows fetched to increase performance (optional)
cursor.arraysize = 100000000

# execute a query (return the number of rows to fetch)
cursor.execute('SELECT * FROM test')

result = cursor.fetchall()
print(result)
for r in result:
    print(r)
    print(r[1])
