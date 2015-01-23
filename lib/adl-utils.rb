require 'middleman-core'
require 'active_support/core_ext'
require 'adl-utils/commands'

::Middleman::Extensions.register(:ADLUTILS) do
  require 'adl-utils/extension'
  require 'adl-utils/helpers'
  ::Middleman::ADLUTILS
end
