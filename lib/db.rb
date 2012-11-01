
class DB

  def initialize
    # create the tables
    execute("CREATE TABLE IF NOT EXISTS messages (id #{autoincrement}, data VARCHAR(255));")
    execute("CREATE TABLE IF NOT EXISTS summary (name VARCHAR(50) PRIMARY KEY, value INTEGER);")

    # seed the database if necessary
    results = execute "SELECT * FROM summary WHERE name = 'message_count';"
    execute "INSERT INTO summary (name, value) VALUES ('message_count', 0);" if results.flatten.empty?

    @initialized = true
  end

  def autoincrement
    raise NotImplementedError, "subclasses must implement the autoincrement method"
  end

  def execute(sql, *args)
    raise NotImplementedError, "subclasses initialize must call super" unless @initialized
    raise NotImplementedError, "subclasses must implement the execute method"
  end

end

require 'sqlite3'
class SQLite3DB < DB

  def initialize(db_filename=File.join(File.dirname(__FILE__), '../db/database_concurrency.sqlite3'))
    @db = SQLite3::Database.new db_filename
    super()
  end

  def autoincrement
    "INTEGER PRIMARY KEY"
  end

  def execute(sql, *args)
    @db.execute(sql, *args)
  end

end

begin
  require 'pg2'

  class PostgresqlDB < DB
    def initialize(host="localhost", port=5432, dbname="database_concurrency", login=ENV["LOGNAME"], password="")
      # host, port, options, tty, dbname, login, password
      @db = PGconn.connect host, port, "", "", dbname, login, password
      super()
    end

    def autoincrement
      "SERIAL"
    end

    def execute(sql, *args)
      n = 0
      while sql =~ /\?/
        sql = sql.sub(/\?/, "$#{n+=1}") 
      end

      @db.exec(sql, *args).values
    end
  end
  
rescue LoadError => e
  $stderr.puts "WARNING: Could't require 'pg' -- PostgreSQL server and gem need to be installed before running on PostgreSQL."
end

begin
  require 'mysqlx'

  class MysqlDB < DB
    def initialize(host="localhost", user="root", password="", database="database_concurrency")
      @db = Mysql.new host, user, password, database
      super()
    end

    def autoincrement
      "INT PRIMARY KEY AUTO_INCREMENT"
    end

    def execute(sql, *args)
      array = []
      rs = nil
      if sql.include? '?'
        pst = @db.prepare sql
        rs = pst.execute *args
      else
        rs = @db.query sql
      end
      unless rs.nil?
        rs.each { |row| array << row } if rs.num_rows > 0
      end
      array
    end
  end

rescue LoadError => e
  $stderr.puts "WARNING: Could't require 'mysql' -- MySQL server and gem need to be installed before running on MySQL."
end
