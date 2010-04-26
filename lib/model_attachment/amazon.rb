module ModelAttachment
  module AmazonInstanceMethods
    
    # returns the aws url
    def aws_url(type = "")
      begin
        return AWS::S3::S3Object.find(aws_key(type), default_bucket).url
      rescue
        log("Could not get object: #{aws_key(type)}")
      end
    end
    
    # sets the default aws bucket
    def default_bucket(current_bucket = 'globalfolders')
      current_bucket
    end

    # creates the aws_key
    def aws_key(type = "")
      file = (type.nil? || type == "" ? filename : basename + "_" + type + extension)
      (path + file).gsub!(/^\//,'')
    end
      
    # connect to aws, uses access_key_id and secret_access_key in config/amazon.yml
    def aws_connect
      return if AWS::S3::Base.connected?
    
      begin
        config = YAML.load_file(self.class.attachment_options[:aws]) 
        if config
          log("Connect to Amazon")
          AWS::S3::Base.establish_connection!(
            :access_key_id     => config['access_key_id'],
            :secret_access_key => config['secret_access_key'],
            :use_ssl           => true,
            :persistent        => true  # if issues with disconnections, set to false
          )
        else
          raise "You must provide an amazon.yml config file"
        end
      rescue AWS::S3::ResponseError => error
        log("Could not connect to amazon: #{error.message}")
      end
    end
  
    # moves file to amazon along with modified images, removes local images once object existence is confirmed
    def move_to_amazon
      aws_connect
      
      log("Move #{aws_key} to Amazon.")
      begin
        AWS::S3::S3Object.store(aws_key, open(full_filename), default_bucket, :content_type => content_type)
        
        # copy over modified files
        process_image_types do |name, value|
          AWS::S3::S3Object.store(aws_key(name.to_s), open(full_filename), default_bucket, :content_type => content_type)
        end
        
        self.bucket = default_bucket
        @dirty = true
        save!
      rescue AWS::S3::ResponseError => error
        log("Store Object Failed: #{error.message}")
      rescue StandardError => e
        log("Move to Amazon Failed: #{e.message}")
      end
    
      begin 
        if AWS::S3::S3Object.exists?(aws_key, default_bucket)
          log("Remove Filename #{full_path + filename}")
          FileUtils.rm(full_path + filename)
        end
        
        # remove any modified local files
        process_image_types do |name, value|
          if AWS::S3::S3Object.exists?(aws_key(name.to_s), default_bucket)
            log("Remove Filename #{full_path + filename(name)}")
            FileUtils.rm(full_path + filename(name.to_s))
          end
        end
      rescue AWS::S3::ResponseError => error
        log("Could not check objects existence: #{error.message}")
      rescue StandardError => error
        log("Removing file failed: #{error.message}.")
      end
    end
  
    # moves files back to local filesystem, along with modified images, removes from amazon once they are confirmed locally
    def move_to_filesystem
      aws_connect
      begin 
        open(full_filename, 'w') do |file|
          AWS::S3::S3Object.stream(path + file_name, default_bucket) do |chunk|
            file.write chunk
          end
        end
        
        # copy over modified files
        process_image_types do |name, value|
          open(full_filename(name), 'w') do |file|
            AWS::S3::S3Object.stream(path + filename(name), default_bucket) do |chunk|
              file.write chunk
            end
          end
        end
        
      rescue AWS::S3::ResponseError => error
        log("Copying File to local filesystem failed: #{error.message}")
      end
    
      if File.size(full_filename) == file_size
        remove_from_amazon
      end
    end

    # removes files from amazon
    def remove_from_amazon
      begin
        log("Removing #{aws_key} from Amazon")
        object = AWS::S3::S3Object.find(aws_key, default_bucket)
        object.delete
        
        # remove modified files
        process_image_types do |name, value|
          AWS::S3::S3Object.find(aws_key(name.to_s), default_bucket).delete
        end

        # make sure we set the bucket to nil so we know they're local
        self.bucket = nil
        @dirty = true
        save!
      rescue AWS::S3::ResponseError => error
        log("Removing file from amazon failed: #{error.message}")
      rescue StandardError => e
        log("Failed remove from Amazon: #{e.message}")
      end
    end
  
  end
end