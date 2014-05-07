# adl-utils

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

`format_price(price_value)`  
 This will add the right currency automatically for you depending on the page locale.  

`is_ca` or `is_us`  
Helps to make content specific for that country using conditionnals  

`page_class`  
Generate class using page name and locale  

`sanitize_clean(string)`    
Will replace special characters with regular ones and replace spaces with dashes.  

**Example:**
> sanitize_clean('spécial string')  
> => special-string  

`newline2br(two_line_string)`  
Will check for `\n` inside the variable and replace it with a `<br />`  

**Example:**
> newline2br('this is an\nexample')  
> => this is an`<br />`example

`supprice(price)`  
Will search for currency and wrap it inside a `<sup>` tag

`convert_class(number colums)`  
Will remove the 'columns' string and use the integer to generate the class
  
**Example:**  
> convert_class('8 columns')  
> => adl-col8
   
