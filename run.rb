require 'rubygems'
require 'zip'
require 'yaml'
require 'json'
require 'fileutils'


class Config

# Constructor
        def initialize( modsPath = "./mods/", configPath = "./config/", configFile = "mods.yml" )
           @modsPath = modsPath
           @configFile = configFile
           @configPath = configPath
           
           if ( ! Dir.exists? @configPath )
               Dir.mkdir( @configPath )
           end
           if ( ! File.exist? @configPath + @configFile )
               file = File.new( @configPath + @configFile, "w+" )
           end
           if ( ! Dir.exist? @modsPath )
               puts "Error! Path to mods folder does not exist!"
               return nil
           end
        end
        
# Adds mods to config file
        def append( filename = "", modslug = "", gameversion = "", version = "" )
            fileAppend = File.new( @configPath + @configFile, 'a' ) #r+
            fileRead = File.new( @configPath + @configFile, 'r' ) 
            
            entry = {
                modslug => {
                        "version" => version,
                        "gameversion" => gameversion,
                        "filename" => filename
                    }
                }
            
# Append to file if file is empty. This is necessary to avoid generate initial yml file.
            if ( File.zero? fileRead )
                fileAppend.write ( entry.to_yaml )
                fileRead.close()
                fileAppend.close()
                
# If mods.yml is not empty, append by combining mods.yml file. This is necessary to prevent headers from being printed.
            else
                data = YAML.load( fileRead ) 
                merged = data.merge( entry )
                fileWrite = File.new( @configPath + @configFile, 'w' )
                fileWrite.write( YAML.dump ( merged ) )
                fileWrite.close()
            end
        end
        
# If mods.yml already has mod listed, update. If not, go to append method to populate that mod.
        def update( filename = "", modslug = "", gameversion = "", version = "" )
            file = File.new( @configPath + @configFile, 'r+' )
            data = YAML.load( file )
            
            if ( filename == "." || filename == ".." )
                return nil
            end

            if ( ! File.zero? file )
                if ( data.key?( modslug ) )
                    data[modslug]["filename"] = filename
                    data[modslug]["gameversion"] = gameversion
                    data[modslug]["version"] = version
                    fileWrite = File.new( @configPath + @configFile, 'w' )
                    fileWrite.write ( data.to_yaml )
                    fileWrite.close()
                    file.close()
                    return nil
                end
            end

            file.close()
            append( filename, modslug, gameversion, version )
        end
        
# Get information from mcmod.info and litemod.json and pass that information to update method, which will pass to append method if necessary.
        def populate()
            puts "Working on directory: #{@modsPath}"
            
# Initalize variables
            modslug = ""
            version = ""
            gameversion = ""
            filename = ""
            found = false
            
# Loop through all files in the mods directory
            Dir.foreach( @modsPath ) do | current |
                
                absolute = @modsPath.to_s + current.to_s
                puts "Currently populating: #{current}"
                
# If the file ends with .jar, for forge mods.
                if ( File.extname( current ) == ".jar" )
                    Zip::File.open ( absolute ) do | zip_file |
                        if ( zip_file.find_entry( "mcmod.info" ) != nil )
                            info = zip_file.read( "mcmod.info" )
                            begin
                                json = JSON.parse( info )[ 0 ]
                                modslug = json['modid']
                                gameversion = json['mcversion']
                                version = json['version']
                                found = true
                                zip_file.close()
                            rescue # Some mod devs have broken mcmod.info or weird parsing. This will prevent exceptions.
                                zip_file.close()
                                found = false
                            end
                        else # Some mods don't even contain mcmod.info!
                            found = false
                            zip_file.close()
                        end
                    end

# If the file ends with .litemod, for litemods.
                elsif ( File.extname( current ) == ".litemod" )
                    Zip::File.open ( absolute ) do | zip_file |
                        if ( zip_file.find_entry ( "litemod.json" ) )
                            found = true
                            info = zip_file.read( "litemod.json" )
                            
                            json = JSON.parse( info )
                            modslug = json['name']
                            version = json['version']
                            gameversion = json['mcversion']
                        end
                    end
                end
                
                filename = current

# If the loop above was not able to obtain information automatically, default back to filename.
                if ( found == false )
                    modslug = current
                    gameversion = "NotKnown"
                    version = "NotKnown"
                end

                update( filename, modslug.downcase, gameversion, version )
            end
        end
end

#
# This class uses generated mods.yml and creates .zip files for solder installation.
#

class Solder

# Constructor
    def initialize ( modsPath = "./mods/", configPath = "./config/", configFile = "mods.yml", outputPath = "./output/" )
        @modsPath = modsPath
        @configPath = configPath
        @configFile = configFile
        @outputPath = outputPath
    end

# Create folders in the output directory for archiving
    def populate_folders
        configFile = File.new( @configPath + @configFile, 'r' )
        configHash = YAML.load( configFile )
        if ( ! File.zero? configFile )
            configHash.each do | key, value |
                directory = @outputPath + key + "/" + configHash[key]["gameversion"] + "/" + configHash[key]["version"]
                puts directory
                FileUtils.mkdir_p( directory )
            end
        end
        end
# Create a copy of mods in the mods folder, to the directory we've just created.
    def populate_mods
        configFile = File.new( @configPath + @configFile, 'r' )
        configHash = YAML.load( configFile )
        
        if ( ! File.zero? configFile )
            configHash.each do | key, value |
                file = @modsPath + configHash[key]["filename"]
                destination = @outputPath + key + "/" + configHash[key]["gameversion"] + "/" + configHash[key]["version"]

                if ( ! File.exist? destination + configHash[key]["filename"] )
                    FileUtils.cp( file, destination )
                end
            end
        end
    end
end

#
# Essentially main method.
#

# Create new object for config
config = Config.new()
config.populate()

# Stop and prompt the user to edit the config
puts "Please edit the config file to ensure that all mods have correct: "
puts "  * name: "
puts "  * version: "
puts "Hit ENTER when you are done."
answer = gets.chomp!

# Create new object for Solder
action = Solder.new()
action.populate_folders()
action.populate_mods()
