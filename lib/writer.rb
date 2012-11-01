require_relative 'db'


module Writer

  SOME_THINGS = [ "apples", "cake", "the color red", "dinosaurs" ]

  def self.insert_messages(db, howmany=(10 * rand).floor)
    # Yes, this is contrived.
    #
    # We're going to insert between 0 and 10 rows to one table, then update a counter in another.
    # This is only here to demonstrate what happens when multiple processes are competing for the
    # same database.
    howmany.times do

      # Start a transaction to make sure all of the database updates happen atomically.
      # Depending on the underlying database implementation (i.e., SQLite, PostgreSQL, or MySQL),
      # this will cause some part of the database to be "locked" (unavailable for use by other
      # connections).
      db.execute "BEGIN"

      message = "I like #{SOME_THINGS[(SOME_THINGS.length * rand).floor]}."
      db.execute "INSERT INTO messages (data) VALUES (?)", message
      message_count = db.execute("SELECT COUNT(*) FROM messages;").flatten[0]
      db.execute "UPDATE summary SET value = ? WHERE name = 'message_count';", message_count

      # Make the transaction take a long time to cause contention on the database.
      sleep 1 * rand

      # End the transaction and release any database locks.
      db.execute "COMMIT"
    end
    howmany
  end
  
end


DB_CLASSES = { "sqlite3" => SQLite3DB, "postgresql" => PostgresqlDB, "mysql" => MysqlDB }

howmany = 0
begin
  raise ArgumentError, "Usage: #{File.basename($0)} <sqlite3 | postgresql | mysql>" unless ARGV.length == 1 && DB_CLASSES.keys.include?(ARGV[0])

  # Instantiate a DB class based on the argument passed-in.
  db = DB_CLASSES[ARGV[0]].new

  print "Started ... "
  $stdout.flush

  # Just loop forever, or until interrupted (e.g., CTRL-C or Unix 'kill' command).
  while true
    howmany += Writer.insert_messages db
  end
rescue ArgumentError => e
  puts e.message
  exit 1
rescue SignalException => e
  puts " ... interrupted. Inserted #{howmany} messages into the database."
  exit 0
end
