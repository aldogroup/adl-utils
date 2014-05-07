# adl-utils
---
##Informations about the gem
##### What is this gem ?
Set of tools for ALDO Group to be used with middleman. It's goal is to centralize helpers, modules, that we use everyday across all the banners. (see the list of features that this gem adds)

##### List of features

- Easy Impex Generation
- Git Release
- Start as Middleman as daemon (works only on unix based system)
- Rebuild your build folder for easing the Web Admins upload task
- Akamai Sync

##### Installation

- First, you need to add in your Gemfile this line:  
`gem 'adl-utils', :git => 'https://github.com/aldogroup/adl-utils'`
- Then you need to update your gems by using this command:  
`bundle install`

##Commands Line

###Impex

**Usage:**  
`middleman impex [options]`  

**Options:**  
`-b  # Run middleman build before generating impex files`
`-e  # Specify environment for generating impex files (Default: dev)`

 **Example:**  
`middleman impex -b -e staging`  
In this example, middleman will build the project then generate the impex files for staging environment

  
- - -

###Release

**Usage:**  
`middleman release [options]`

**Options:**  
`-b  # Run middleman build before creating the release`
`-e  # Specify environment for the release(Default: dev)`
`-p  # version (icongo or hybris) (Default: icongo)`  
  
- - -

###Daemon
**Usage:**  
`middleman daemon [options]`

**Options:**  
`[--start]    # Start middleman as daemon`  
`[--stop]     # stop the daemon`  
`[--restart]  # restart the daemon`

---

###Rebuild

**Usage:**  
`middleman rebuild [options]`

**Options:**  
`-e, [--environment=ENVIRONMENT]  # Call rebuild task (Default: dev)`  
`-p, [--platform=PLATFORM]        # version (icongo or hybris) (Default: icongo")`

---

###Akamai Sync

**Usage:**  
`middleman akamai_sync [options]`

**Options:**  
`-b  # Run middleman build before creating the release`
`-e  # Specify environment for the release(Default: dev)`
`-p  # version (icongo or hybris) (Default: icongo)`


##Helpers

* `format_price(price_value)`  
   This will add the right currency automatically for you
* `
