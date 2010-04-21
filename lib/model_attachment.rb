# 
#  model_attachment.rb
#  
#  Created by Stephen Walker on 2010-04-21.
#  Copyright 2010 WalkerTek Interactive Marketing. All rights reserved.
# 

require 'model_attachment/upfile'
require 'model_attachment/iostream'

# The base module that gets included in ActiveRecord::Base.
module ModelAttachment
  VERSION = "0.1"
  
  class << self
    # Provides logging configuration
    # * log: Turns logging on, default is true
    def options
      @options ||= {
        log => true
      }
    end
    
    def included base #:nodoc:
      base.extend ClassMethods
    end
    
    # Log a ActsAsAttachment specific message
    def log(message)
      logger.info("[model_attachment] #{message}") if logging?
    end
    
    def logger #:nodoc:
      ActiveRecord::Base.logger
    end
    
    def logging? #:nodoc:
      options[:log]
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
    def has_attachment(options = {})
      include InstanceMethods
       
      write_inheritable_attribute(:attachment_options, options)

      before_save :save_attached_files
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
    
    # Does all the file processing, moves from temp, processes images, sets attributes
    def save_attached_files
      options = self.class.attachment_options
      file    = self.file_name
          
      # get original filename info and clean up for storage
      ext  = File.extname(file.original_filename)
      base = File.basename(file.original_filename, ext).strip.gsub(/[^A-Za-z\d\.\-_]+/, '_')
      
      log("Path: #{path} Basename: #{base} Extension: #{ext}")

      # copy image to correct path
      FileUtils.mkdir_p(full_path)
      FileUtils.chmod(0755, full_path)
      FileUtils.mv(file.path, full_path + base + ext)
      
      # save attributes
      self.file_name    = base + ext
      self.content_type = file.content_type.strip
      self.file_size    = file.size.to_i
      self.updated_at   = Time.now
      
      # run any processing passed in on images
      process_images
      
      @dirty = true 
      file.close
    end
    
    # run each processor on file
    def process_images
      self.class.attachment_options[:types].each do |name, value|
        if content_type =~ /^image\//
          command = value[:command]
          old_filename = full_filename
          new_filename = full_filename(name)
          log("Create #{name} by running #{command} on #{old_filename}")
          log("Created: #{new_filename}")
          `#{command} #{old_filename} #{new_filename}`
        end
      end
    end
    
    # create the path based on the template
    def interpolate(path, *args)
      methods = ["domain", "folder", "document"]
      methods.reverse.inject( path.dup ) do |result, tag|
        result.gsub(/:#{tag}/) do |match|
          send( tag, *args )
        end
      end
    end
    
    # returns the filename, including any type modifier
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
    
    # returns the rails path of the file
    def path 
      "/system/" + interpolate(self.class.attachment_options[:path])
    end
    
    # returns the full system path of the file
    def full_path
      RAILS_ROOT + path
    end
    
    # returns the full system path/filename
    def full_filename(type = "")
      full_path + filename(type)
    end
    
    # removes any files associated with this instance
    def destroy_attached_files
      path = full_filename
      
      begin
        log("Deleting #{path}")
        FileUtils.rm(path) if File.exist?(path)
        
        # delete thumbnails if image
        self.class.attachment_options[:types].each do |name, value|
          if content_type =~ /^image\//
            log("Deleting #{name}")
            FileUtils.rm(full_filename(name)) if File.exists?(full_filename(name))
          end
        end
        
      rescue Errno::ENOENT => e
        # ignore file-not-found, let everything else pass
      end
      begin
        while(true)
          path = File.dirname(path)
          FileUtils.rmdir(path)
        end
      rescue Errno::EEXIST, Errno::ENOTEMPTY, Errno::ENOENT, Errno::EINVAL, Errno::ENOTDIR
        # Stop trying to remove parent directories
      rescue SystemCallError => e
        log("There was an unexpected error while deleting directories: #{e.class}")
        # Ignore it
      end 
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