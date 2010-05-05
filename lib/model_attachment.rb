# 
#  model_attachment.rb
#  
#  Created by Stephen Walker on 2010-04-22.
#  Copyright 2010 Stephen Walker. All rights reserved.
# 

# TODO - Add exception handling and validation testing

require 'rubygems'
require 'yaml'
require 'model_attachment/upfile'
require 'model_attachment/amazon'

# The base module that gets included in ActiveRecord::Base.
module ModelAttachment
  VERSION = "0.0.7"
  
  class << self
    
    def included base #:nodoc:
      base.extend ClassMethods
    end
    
  end
  
  module ClassMethods
    # +has_attachment+ adds the ability to upload files and make thumbnails of images
    # * +path+: the path format for saving the documents
    # * +types+: a hash of thumbnails to create for images
    #            :types => {
    #                 :small => { :command => 'convert -geometry 100x100' },
    #                 :large => { :command => 'convert -geometry 500x500' }
    #            }
    # * +aws+: the path to the aws config file or :default for rails config/amazon.yml
    #          access_key_id:
    #          secret_access_key: 
    # * +logging+: set to true to see logging
    def has_attachment(options = {})
      include InstanceMethods
      
      if options[:aws]
        begin
          require 'aws/s3'
        rescue LoadError => e
          e.messages << "You man need to install the aws-s3 gem"
          raise e
        end
      end
    
      if options[:aws] == :default
        config_file = File.join(RAILS_ROOT, "config", "amazon.yml")
        if File.exist?(config_file)
          options[:aws] = config_file
          include AmazonInstanceMethods
        else
          raise("You must provide a config/amazon.yml setup file")
        end
      elsif !options[:aws].nil? && File.exist?(options[:aws])
        include AmazonInstanceMethods
      end
      
      write_inheritable_attribute(:attachment_options, options)
        
      # must be before the save to save the attributes
      before_save :save_attributes
      
      # must be after save to get the id for the path
      after_save :save_attached_files
      before_destroy :destroy_attached_files
      
    end

    
    # Places ActiveRecord-style validations on the size of the file assigned. The
    # possible options are:
    # * +in+: a Range of bytes (i.e. +1..1.megabyte+),
    # * +less_than+: equivalent to :in => 0..options[:less_than]
    # * +greater_than+: equivalent to :in => options[:greater_than]..Infinity
    # * +message+: error message to display, use :min and :max as replacements
    # * +if+: A lambda or name of a method on the instance. Validation will only
    #   be run is this lambda or method returns true.
    # * +unless+: Same as +if+ but validates if lambda or method returns false.
    def validates_attachment_size name, options = {}
      min     = options[:greater_than] || (options[:in] && options[:in].first) || 0
      max     = options[:less_than]    || (options[:in] && options[:in].last)  || (1.0/0)
      range   = (min..max)
      message = options[:message] || "file size must be between :min and :max bytes."
      message = message.gsub(/:min/, min.to_s).gsub(/:max/, max.to_s)

      validates_inclusion_of name,
                             :in      => range,
                             :message => message,
                             :if      => options[:if],
                             :unless  => options[:unless]
    end

    # Places ActiveRecord-style validations on the presence of a file.
    # Options:
    # * +if+: A lambda or name of a method on the instance. Validation will only
    #   be run is this lambda or method returns true.
    # * +unless+: Same as +if+ but validates if lambda or method returns false.
    def validates_attachment_presence name, options = {}
      message = options[:message] || "must be set."
      validates_presence_of name, 
                            :message => message,
                            :if      => options[:if],
                            :unless  => options[:unless]
    end
    
    # Returns attachment options defined by each call to acts_as_attachment.
    def attachment_options
      read_inheritable_attribute(:attachment_options)
    end
    
  end
  
  module InstanceMethods #:nodoc:
    
    # return the url based on location
    # * +proto+: set the protocol, defaults to http
    # * +port+: sets the port if required
    # * +server_name+: sets the server name, defaults to localhost
    # * +path+: sets the path, defaults to /documents/send
    # * +type+: sets the type, types come from the has_attachment method, ex. small, large
    def url(options = {})
      proto       = options[:proto]        || "http"
      port        = options[:port]
      server_name = options[:server_name]  || "localhost"
      url_path    = options[:path]         || "/#{self.class.to_s.downcase.pluralize}/deliver/"
      type        = options[:type]
      server_name += ":" + port.to_s if port
      type_string = "?type=#{type}" if type
      
      unless self.class.attachment_options[:aws]
        bucket = nil
      end
      
      # if files are public, serve public url
      if public?
        url_path = path.gsub(/^\/public(.*)/, '\1')
        type_string = "_#{type}" if type
        url = "#{proto}://#{server_name}#{url_path}#{basename}#{type_string}#{extension}"
      elsif !bucket.nil?
        # if bucket is set, then use aws url
        aws_url(type)
      else
        # otherwise use private url with deliver
        url = "#{proto}://#{server_name}#{url_path}#{id}#{type_string}"
      end
      
      log("Providing URL: #{url}")
      return url
    end
    
    def public?
      (path =~ /^\/public/)
    end
    
    # returns the rails path of the file
    def path 
      if (self.class.attachment_options[:path]) 
        return interpolate(self.class.attachment_options[:path])
      else 
        return "/public/#{self.class.to_s.downcase.pluralize}/" + sprintf("%04d", id) + "/"
      end
    end
    
    # returns the full system path of the file
    def full_path
      RAILS_ROOT + path
    end
    
    # returns the filename, including any type modifier
    # +type+: type from has_attachment, ex. small, large
    def filename(type = "")
      type      = "_#{type}" if type != ""
      "#{basename}#{type}#{extension}"
    end
    
    def extension #:nodoc:
      File.extname(file_name)
    end
    
    def basename #:nodoc:
      File.basename(file_name, extension)
    end
     
    # returns the full system path/filename
    # +type+: type from has_attachment, ex. small, large
    def full_filename(type = "")
      full_path + filename(type)
    end
    
    # decide whether or not this is an image
    def image?
      content_type =~ /^image\//
    end
    
    # create the path based on the template
    def interpolate(path, *args)
      #methods = ["domain", "folder", "document", "version", "user", "account"]
      self.class.instance_methods(false).sort.reverse.inject( path.dup ) do |result, tag|
        #$stderr.puts("Result: #{result} Tag: #{tag}")
        result.gsub(/:#{tag}/) do |match|
          send( tag, *args )
        end
      end
    end
    
    private
    
    def process_image_types #:nodoc:
      if self.class.attachment_options[:types]
        self.class.attachment_options[:types].each do |name, value|
          if image?
            yield(name, value)
          end
        end
      end
    end
    
    # save the correct attribute info before the save
    def save_attributes
      return if file_name.nil? || file_name.class.to_s == "String"
      @temp_file = self.file_name
      
      # get original filename info and clean up for storage
      ext  = File.extname(@temp_file.original_filename)
      base = File.basename(@temp_file.original_filename, ext).strip.gsub(/[^A-Za-z\d\.\-_]+/, '_')
      
      # save attributes
      self.file_name    = base + ext
      self.content_type = @temp_file.content_type.strip
      self.file_size    = @temp_file.size.to_i
      self.updated_at   = Time.now
      
    end
    
    # Does all the file processing, moves from temp, processes images
    def save_attached_files
      return if @temp_file.nil? or @temp_file == ""
      options = self.class.attachment_options
            
      log("Path: #{path} Basename: #{basename} Extension: #{extension}")

      # copy image to correct path
      FileUtils.mkdir_p(full_path)
      FileUtils.chmod(0755, full_path)
      FileUtils.mv(@temp_file.path, full_path + basename + extension)

      # run any processing passed in on images
      process_images
      
      @dirty = true 
      @temp_file.close if @temp_file.respond_to?(:close)
      @temp_file = nil
    end
        
    # run each processor on file
    def process_images
      process_image_types do |name, value|
        command = value[:command]
        old_filename = full_filename
        new_filename = full_filename(name)
        log("Create #{name} by running #{command} on #{old_filename}")
        log("Created: #{new_filename}")
        `#{command} #{old_filename} #{new_filename}`
      end
    end
    
    # removes any files associated with this instance
    def destroy_attached_files
      begin
        
        if bucket.nil?
          log("Deleting #{full_filename}")
          FileUtils.rm(full_filename) if File.exist?(full_filename)
        
          # delete thumbnails if image
          process_image_types do |name, value|
            log("Deleting #{name}")
            FileUtils.rm(full_filename(name)) if File.exists?(full_filename(name))
          end
        
        else 
          remove_from_amazon
        end
        
      rescue Errno::ENOENT => e
        # ignore file-not-found, let everything else pass
      end
      begin
        while(true)
          dir_path = File.dirname(full_filename)
          FileUtils.rmdir(dir_path)
        end
      rescue Errno::EEXIST, Errno::ENOTEMPTY, Errno::ENOENT, Errno::EINVAL, Errno::ENOTDIR
        # Stop trying to remove parent directories
      rescue SystemCallError => e
        log("There was an unexpected error while deleting directories: #{e.class}")
        # Ignore it
      end 
    end
    
    def logging? #:nodoc:
      self.class.attachment_options[:logging]
    end
    
    # Log a ModelAttachment specific message
    # +message+: message to be logged if logging? true
    def log(message)
      logger.info("[model_attachment] #{message}") if logging?
    end
  
    def dirty? #:nodoc:
      @dirty
    end
    
  end
  
end

# Set it up in our model
if Object.const_defined?("ActiveRecord")
  ActiveRecord::Base.send(:include, ModelAttachment)
  File.send(:include, ModelAttachment::Upfile)
end
