require 'rubygems'
require 'fog'


az_zones=["az-1.region-a.geo-1","az-2.region-a.geo-1","az-3.region-a.geo-1"]

def create_connection(az_id)

    @conn = Fog::Compute.new(
       :provider      => "HP",
       :hp_account_id  => ENV['HP_ACCOUNT_ID'],
       :hp_secret_key =>  ENV['HP_SECRET_KEY'],
       :hp_auth_uri   =>  ENV['HP_AUTH_URI'],
       :hp_tenant_id =>   ENV['HP_TENANT_ID'],
       :hp_avl_zone => az_id,
       :hp_use_upass_auth_style => "true")
end



#az_zones.each { |x| puts "#{x} zone instaces detected: #{create_connection(x).servers.size}"}

# Get all instances
  #instances = conn.servers # initialized from above
 # puts "Total instances detected #{instances.size}"

def instances_by_owner(sample_az)
# Define hash as place holders for data and pull data from HP Console
  total_instance, held_machines = Hash.new(0), Hash.new(0)
  create_connection(sample_az)
  
# Get List of Instance 'owners' by PPK name
  result = @conn.servers.inject([]) { |result,h| result << h.key_name unless result.include?(h.key_name); result }

# Create Hash of Total Instances owned by each PPK that are also in active state aka running
  result.each do |v| @conn.servers.each do |n|
        held_machines[v] +=1 if v == n.key_name && n.state=~/ACTIVE/
        # total_instance[v] +=1 if v == n.key_name -- not needed.
        end
 end
 puts held_machines.to_yaml
end



# Get all instances
  az_zones.each { |x| puts "#{x} zone instaces detected: #{create_connection(x).servers.size}"}
  az_zones.each { |x|  instances_by_owner(x)}
