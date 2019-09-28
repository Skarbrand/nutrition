require 'sqlite3'
require 'yaml'

class Database

	def initialize
		dbfile = 'Nutrition.sqlite'
		@db_handle = SQLite3::Database.open dbfile
		@db_handle.results_as_hash = true
		@db_handle_user = nil
		@unused_file = YAML.load_file('unused_ingridients.yaml')
		@unused_user = []
	end
	
	def load_userSettings
		dbfile_user = 'User.sqlite'
		if File.file?(dbfile_user)
			@db_handle_user = SQLite3::Database.open dbfile_user
			@db_handle_user.results_as_hash = true
		else
			@db_handle_user = SQLite3::Database.new dbfile_user
			@db_handle_user.execute(
				'CREATE TABLE IF NOT EXISTS
					Ingridient_Settings(
						Nutrition_ID INTEGER,
						Visibility INTEGER)'
			)
			self.list_ingridients_ids.each do |row|
				@db_handle_user.execute('
					INSERT INTO
						Ingridient_Settings
					VALUES
						(' + row.to_s + ',1)'
				)
				#@unused_user << row
			end
		end
	end
	
	def read_ingridient(ndb_id)
		ingridient = Ingridient.new
		if ndb_id.length == 5
			query = 'SELECT * FROM 
						FOOD_DESC 
					INNER JOIN 
						NUTR_DEF, NUT_DATA 
					ON 
						FOOD_DESC.NDB_ID = NUT_DATA.NDB_ID AND 
						NUT_DATA.Nutrition_ID = NUTR_DEF.Nutrition_ID 
					WHERE 
						FOOD_DESC.NDB_ID = "' + ndb_id.to_s + '" AND '
			query = self.filter_unused(query,'NUTR_DEF')
			query << " AND "
			query = self.filter_unused_user(query,'NUTR_DEF')
			@db_handle.execute(query) do |row|
				ingridient.id = row['NDB_ID'] unless ingridient.id != nil
				ingridient.name = row['Long_Desc'] unless ingridient.name != nil
				ingridient.shortname = row['Shrt_Desc'] unless ingridient.shortname != nil
				ingridient.nutrition.merge!(
					row['Nutrition_Name'] => row['Nutrition_Value'] + ' ' + row['Units']
				)
			end
		end
		return ingridient
	end


	def	search_ingridient(search_string, search_page)

		result = {
			:data => [],
			:count => 0
		}

		query = 'SELECT NDB_ID, Long_Desc FROM FOOD_DESC WHERE
					Long_Desc
				LIKE "%' + search_string + '%"
				ORDER BY Long_Desc ASC 
				LIMIT ' + 100.to_s + '
				OFFSET ' + ((search_page) * 100 ).to_s
		stm = @db_handle.prepare(query)
		if !search_string.empty?
			stm.execute.each do |row|
				result[:data] << [row['NDB_ID'],row['Long_Desc']]
			end
		end
		
		query = 'SELECT Count(NDB_ID) FROM FOOD_DESC WHERE
					Long_Desc
				LIKE "%' + search_string + '%"'
		if !search_string.empty?
			result[:count] = @db_handle.get_first_value(query)
		end
		
		return result
	end

	
	def change_substance_userset(ndb_id,userset)
		query = 'UPDATE
					Ingridient_Settings
				SET
					Visibility = ' + userset.to_s +
				' WHERE
					Nutrition_ID = ' + ndb_id.to_s
		@db_handle_user.execute(query)
	end

	def read_ingridient_custom(ingridient_object)
		query = 'SELECT * FROM
					Ingridient_custom
				WHERE
					NDB_ID = ' + ingridient_object.id
			@db_handle_user.execute(query).each do |row|
				ingridient_object.customname = row['Name_custom']
				ingridient_object.price = row['Price']
			end
		return ingridient_object
	end
	
	def check_ingridient_custom(ndb_id,name_custom)
		result = true
		query = 'SELECT 
					NDB_ID, Name_custom 
				FROM 
					Ingridient_custom
				WHERE
					Name_custom = ?'
		stm = @db_handle_user.prepare(query)
		stm.bind_params name_custom
		stm.execute.each do |row|
			if row['NDB_ID']!=ndb_id
				result = false
				break
			end
		end
		return result
	end
	
	def search_recipe(name)
		result = nil
		query = 'SELECT 
					id, name
				FROM
					Recipe_custom
				WHERE
					name = ?'
		stm = @db_handle_user.prepare(query)
		stm.bind_params name
		stm.execute.each do |row|
			result = row['id']
		end
		return result
	end
	
	def update_recipe(name, ingridients, id=nil)
		if id==nil
			query = 'INSERT INTO
						Recipe_custom
						(id, name)
					VALUES (null, ?)'
			stm = @db_handle_user.prepare(query)
			stm.bind_params name
			stm.execute
			
			query = 'INSERT INTO'
			stm.bind_params nil,search_recipe(name)
			stm.execute
		else
			query = 'UPDATE'
		end	
	end

	def update_ingridient_custom(ndb_id, price, name_custom)
		query = 'REPLACE INTO
					Ingridient_custom
					(NDB_ID, Price, Name_custom)
				VALUES (?, ?, ?)'
		stm = @db_handle_user.prepare(query)
		stm.bind_params ndb_id, price, name_custom
		stm.execute
	end
	
	def delete_ingridient_custom(ndb_id)
		query = 'DELETE FROM Ingridient_custom WHERE NDB_ID=?'
		stm = @db_handle_user.prepare(query)
		stm.bind_params ndb_id
		stm.execute
	end
	
	def list_substances
		result = Hash.new
		query = 'SELECT Tagname, Nutrition_ID, Nutrition_Name FROM NUTR_DEF WHERE '
		query = self.filter_unused(query)
		@db_handle.execute(query) do |row|
			substance = Substance.new
			substance.id = row['Nutrition_ID']
			substance.name = row['Nutrition_Name']
			substance.tagname = row['Tagname']
			result.merge!(substance.id => substance)
		end
		query = "SELECT * FROM Ingridient_Settings"
		@db_handle_user.execute(query) do |row|
			result[row['Nutrition_ID']].userset = row['Visibility']
		end
		return result
	end
	
	def list_bookmark_ids
		result = []
		query = 'SELECT * FROM Ingridient_Custom'
		@db_handle_user.execute(query).each do |row|
			result << row['NDB_ID']
		end
		return result
	end

	def list_bookmarks
		result = {}
		query = 'SELECT * FROM Ingridient_Custom'
		@db_handle_user.execute(query).each do |row|
			result[row['Name_custom']] = row['NDB_ID']
		end
		return result
	end
	
	def filter_unused(query,dbPrefix=nil)
		@unused_file.each do |unused_entry|
			query << dbPrefix + '.' if dbPrefix != nil
			query << 'Nutrition_ID !=' + unused_entry.to_s + ' AND '
		end
		query = query[0...-4]
		return query
	end

	def filter_unused_user(query,dbPrefix=nil)
		listquery = "SELECT * FROM Ingridient_Settings"
		@unused_user = []
		@db_handle_user.execute(listquery) do |row|
			@unused_user << row['Nutrition_ID'] if row['Visibility'] == 0
		end
		@unused_user.each do |unused_entry|
			query << dbPrefix + '.' if dbPrefix != nil
			query << 'Nutrition_ID != ' + unused_entry.to_s + ' AND '
		end
		query = query[0...-4]
		return query
	end
	
end

class Ingridient
	attr_accessor :id, :name, :shortname, :nutrition, :customname, :price
	def initialize
		@id = nil
		@name = nil
		@shortname = nil
		@nutrition = Hash.new
		@customname = nil
		@price = nil
	end
end

class Substance
	attr_accessor :id, :name, :tagname, :userset
	def initialize
		@id = nil
		@name = nil
		@tagname = nil
		@userset = nil
	end
end
