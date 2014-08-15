# ALDO Utilities [![Code Climate](https://codeclimate.com/github/aldogroup/adl-utils/badges/gpa.svg)](https://codeclimate.com/github/aldogroup/adl-utils) [![Test Coverage](https://codeclimate.com/github/aldogroup/adl-utils/badges/coverage.svg)](https://codeclimate.com/github/aldogroup/adl-utils)


- [Introduction](#introduction)
- [Installation](#installation)
- [Command Line](#command-line)
  - 	[Daemon](#daemon)
  -   [Rebuild](#rebuild)
  -   [Impex](#impex)
  -   [Release](#release)
  -   [Akamai Sync](#akamai-sync)

- [Helpers](#helpers)
  -   [Price formatter](#price-formatter)
  -   [Country conditionals](#country-conditionals)
  -   [Page classes](#page-classes)
  -   [Sanitize clean](#sanitize-clean)
  -   [Supprice](#supprice)
  -   [Convert class](#convert-class)

Introduction
------------

A set of tools that we use at the ALDO Group for our Middleman applications.
 Our goal is to create a common playground for centralizing our helpers and modules that we use everyday.

**List of features**

-   Run Middleman as a Daemon (only unix based systems) (Still in Development)
-   Tag our Git releases (Still in Development)
-   Generate impex files for Hybris
-   Cleanly restructure the build folder
-   Sync with the Akamai server

* * * * *

Installation
------------

Add the following to your Gemfile:
 `gem 'adl-utils', :git => 'https://github.com/aldogroup/adl-utils'`

Then simply run `bundle install` to install/update the gems.

In order to use middleman with the multiple environments and platforms easily, you can use these:
 [aliases](https://gist.github.com/blabassi/8b0cd7e46794ca306e2f) (highly recommended but not mandatory)
 Add them to your `~/.zshrc` or `~/.bashrc` file. You will be able to start middleman with:
 - `icongo` Create Aliases for Middleman in dev environment for Icongo Platform
 - `hybris` Create Aliases for Middleman in dev environment for Hybris Platform
 - `icongo-staging` Create Aliases for Middleman in staging environment for Icongo Platform
 - `hybris-staging` Create Aliases for Middleman in staging environment for Hybris Platform
 - `icongo-prod` Create Aliases for Middleman in production environment for Icongo Platform
 - `hybris-prod` Create Aliases for Middleman in production environment for Hybris Platform

* * * * *

Command Line
------------

### Daemon

**Usage:**
 `middleman daemon [--options]`

**Options:**
 `--start` Run Middleman as a daemon  
 `--restart` Restart the Middleman daemon  
 `--stop` Stop the Middleman daemon

**Example:**
 `middleman daemon --start`  

Given this example, we boot up a Middleman daemon. You can also restart and stop the daemon.

* * * * *

### Rebuild

**Usage:**  
 `middleman rebuild [--options]`

**Options:**  
 `-e, [--environment=ENVIRONMENT]` The environment to rebuild (Default: 'dev')  
 `-p, [--platform=PLATFORM]` The platform that we want to rebuild (icongo or hybris) (Default: ‘icongo’)

**Example:**
 `middleman rebuild -e prod -p hybris`

Given this example, we restructure the Hybris production build folder generated by Middleman.

* * * * *

### Impex

This command will generate impex files from your build directory.

**Usage:**
 `middleman impex [--options]`

**Without options:**
 It will only generate the impex that goes for the PCM (Landing Pages & Content Pages).  
 It will generate the impex scheduled version that will need to be uploaded first and also the confirm version that will need to be upload after (when the campaign goes live).

**Example of file generated:**  
 `14-08-11_17.12_fall-winter-confirm-on-12-08-2014_14.30.00_ca.impex`  
 `14-08-11_17.12_fall-winter-scheduled-for-12-08-2014_13.30.00_ca.impex`

**Options:**  
 `--homepage` Will generate impex for the homepage without time restriction.  
 `--l3` Will generate all the level3 pages (they need to be build before running this command).

**Example:**  
 `middleman impex -b -e staging`  

Given this example, Middleman will build the project and generate the impex files for our staging environment.

* * * * *

### Release

**Usage:**
 `middleman release [--options]`

**Options:**
 `-b` Run the Middleman build command before creating the release
 `-e` Specify the environment for the release (Default: ‘dev’)
 `-p` The platform that we want to release for (icongo or hybris) (Default: ‘icongo’)\`

**Example:**
 `middleman release -b -e prod -p hybris`

Given this example, Middleman will tag a release for production on our Hybris platform.

* * * * *

### Akamai Sync

**Usage:**
 `middleman akamai_sync [--options]`

**Options:**
 `-b` Run the Middleman build command before creating the release
 `-e` Specify environment for generating impex files (Default: ‘dev’)
 `-p` The platform that we want to release for (icongo or hybris) (Default: ‘icongo’)\`

**Example:**
 `middleman akamai_sync -b -e prod -p hybris`

Given this example, Middleman will sync with our Akamai server for production on our Hybris platform.

* * * * *

Helpers
-------

#### Price formatter

Automatically formats the price depending on the locale.

`format_price(price_value)`

#### Country conditionals

Helps to specify country specific logic using conditionals.

-   US: `is_us`
-   CA: `is_ca`
-   CA-ENG: `is_ca('en')`
-   CA-FRE: `is_ca('fr')`
-   UK: `is_uk`

For instance, if we want to include a module that is going to only be showcased on the US website, in our slim template, do this:

``` {.prettyprint}
- if is_us
    / Include some US logic here /
```

#### Page classes

Generates classes based on the page name and current locale.

`page_class`

#### Sanitize clean

Will replace special characters with regular ones and replace spaces with dashes.

`sanitize_clean(string)`

**Example:**

> sanitize\_clean(‘spécial string’)
>  =\> special-string

`newline2br(two_line_string)`

Will check for `\n` inside the variable and replace it with a `<br />`.

**Example:**

> newline2br(‘this is an\\nexample’)  
>  =\> this is an`<br />`example

#### Supprice

Will search for a currency and wrap it inside a `<sup>` tag.

`supprice(price)`

#### Convert class

Will remove the ‘columns’ string and use the integer to generate the class.

`convert_class(number of columns)`

**Example:**

> convert\_class(‘8 columns’)  
>  =\> adl-col8