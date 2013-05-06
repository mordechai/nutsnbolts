require 'rubygems'
require 'fog'
require 'yaml'
require "net/http"
require "uri"
require 'simple-graphite'
require 'logger'
require './config/config.rb'


class Image <
        Struct.new( :id, :type, :owners)
end

$LOG = Logger.new('logs/application.log', 0, 100 * 1024 * 1024)
@g = Graphite.new({:host => :graphite, :port => 2003})
# need to add output yaml folder for server files /home/ubuntu/projects/console-mgr/code/files
az_zones=["az-1.region-a.geo-1","az-2.region-a.geo-1","az-3.region-a.geo-1"]
def get_av_servers(az_id)
    conn = create_connection(az_id)
    total_servers =  conn.servers.size
    conn = nil
    return total_servers
end

def find_images(some_id, images)

    for iter in 0..images.size
        return iter if images[iter].id == some_id.to_i
    end

end


def create_connection(az_id)

return conn = Fog::Compute.new(
       :provider      => "HP",
       :hp_access_key  => ENV['HP_ACCESS_KEY'],
       :hp_secret_key =>  ENV['HP_SECRET_KEY'],
       :hp_auth_uri   =>  ENV['HP_AUTH_URI'],
       :hp_tenant_id =>   ENV['HP_TENANT_ID'],
       :hp_avl_zone => az_id,
       :hp_use_upass_auth_style => "false",
       :user_agent => "console_mordechai/15.185.230.23",
       :connection_options => { :connect_timeout => 30, :read_timeout => 30, :write_timeout => 30 })

end

def instances_by_owner(sample_az)
# Define hash as place holders for data and pull data from HP Console
  total_instance, held_machines = Hash.new(0), Hash.new(0)
  conn = create_connection(sample_az)

# Get List of Instance 'owners' by PPK name
  result = conn.servers.inject([]) { |result,h| result << h.key_name unless result.include?(h.key_name); result }

# Create Hash of Total Instances owned by each PPK that are also in active state aka running
  result.each do |v| conn.servers.each do |n|
        held_machines[v] +=1 if v == n.key_name && n.state=~/ACTIVE/
        # total_instance[v] +=1 if v == n.key_name -- not needed.
        end
 end
  held_machines.each do |k,v|
    v ||= 0
    push_data("stats.HPCS.#{sample_az}.instances.owner.#{k} #{v} #{@g.time_now}")
  end
conn = nil
end

def store_hash(array1,id,data)

   #get array index of flavor_id_list_result by using flavor_id_list_result.index(@conn.flavor_id)
   #push data which is hash to this flavor_id_list_result to the correct index.

  return  array1[array1.index(id)] << data

end


def instances_by_owner_size(sample_az)
# Define hash as place holders for data and pull data from HP Console
  total_instance, held_machines = Hash.new(0), Hash.new(0)
  total_instance_by_type, total_size_types = Hash.new(0), Hash.new(0)
  list_of_results = Array.new
  ppk_owners = Hash.new(0)
  images = Array.new

  conn = create_connection(sample_az)

# Get List of Instance 'owners' by PPK name
  result = conn.servers.inject([]) { |result,h| result << h.key_name unless result.include?(h.key_name); result }

# Get List of Instance Sizes types by ID @conn.flavors aka server.flavor id
  flavor_id_list_result = conn.flavors.inject([]) { |flavor_id_list_result,h| flavor_id_list_result.to_a << h.id  unless flavor_id_list_result.include?(h.id); flavor_id_list_result }

  flavor_id_list_result.each {|x| images << Image.new( x, '', owners=Hash.new{0})}
  # Get List of Instance Sizes Names @conn.flavors.name
  flavor_name_list = conn.flavors.inject([]) { |flavor_name_list,h| flavor_name_list << h.name unless flavor_name_list.include?(h.name); flavor_name_list }
  flavor_name_list = flavor_name_list.map {|name| name.gsub!('.','_')}


 result.each do |v| conn.servers.each do |n|
        if v == n.key_name  then
           images[find_images(n.flavor_id.to_i,images)].owners[v] +=1
           images[find_images(n.flavor_id.to_i,images)].type = convert_typeId_typeName(n.flavor_id.to_i,conn).to_s
        end
        end
  end
  total_instance_by_type.each do |k, v|
       v ||= 0
       push_data("stats.HPCS.#{sample_az}.instances.size.#{k} #{v} #{@g.time_now}")
  end

 send_type_by_owner(images,sample_az)
 conn = nil
end


def send_type_by_owner(images,sample_az)
 for iter in 0..images.length-1
    images[iter].owners.each do |k,v|
      push_data("stats.HPCS.#{sample_az}.instances.sizePerOwner.#{images[iter].type}.#{k} #{v} #{@g.time_now}")
  end
   end
end
def convert_typeId_typeName(serverid,conn)
    iter = ''
    conn.flavors.each_with_index do |val, id|
      iter = id if val.id == serverid
    end
    flavor_name = @conn.flavors[iter].name
    return flavor_name.gsub!('.','_')
end

def push_data(somedata)
  @g.push_to_graphite do |graphite|
    graphite.puts somedata
  end
end

def do_work(az_zones, zzz)
a_thread = Thread.new{ az_zones.each { |x|  push_data("stats.HPCS.#{x}.instances.total #{get_av_servers(x)} #{@g.time_now}")}; sleep zzz}
b_thread = Thread.new{ az_zones.each { |x|  instances_by_owner(x)}; sleep zzz}
c_thread = Thread.new{ az_zones.each { |x|  instances_by_owner_size(x)}; sleep zzz}

end

begin
  retries = 0

while true
  do_work(az_zones, 230)
  end
rescue Exception => msg
  retries = retries + 1
  $LOG.error  msg
  $LOG.error "going to retry now for #{retries} time"
  @conn = nil
  GC.start
  sleep 20
  retry
end
