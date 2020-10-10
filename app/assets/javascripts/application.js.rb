require 'jquery'
require 'codemirror'
require 'ruby_codemirror'
require 'start_audio_context'

require 'opal'
require 'opal-parser'
require 'opal-jquery'
require 'negasonic'

DEFAULT_TRY_CODE = <<-RUBY
# playing notes in the default cycle
play 62, 63, 65
play 69, 70, 74

# sounds at the same time as the previous notes
cycle do
  play 74, 70, 69
  play 65, 63, 62
end

# add custom effects and a synth
with_instrument(:drums, synth: :membrane, fx: [:distortion, :freeverb], volume: -9) do
  cycle do
    2.times do
     play 30
     play 64
    end
  end

  cycle do
    1.times do
      play 95
      play 64
      play 85
    end
  end
end
RUBY

class TryNegasonic
  class UserActions
		HEADERS = {'X-CSRF-Token' => Element.find('meta[name="csrf-token"]')['content']}

    def initialize
      Element.find('#sign_up').on(:click) do
        show_modal('#sign_up_modal')
      end
      Element.find('.cancel-sign-up').on(:click) do
        hide_modal('#sign_up_modal')
      end
      Element.find('#sign_up_modal .is-success').on(:click) do
        sign_up
      end

      Element.find('#sign_in').on(:click) do
        show_modal('#sign_in_modal')
      end
      Element.find('.cancel-sign-in').on(:click) do
        hide_modal('#sign_in_modal')
      end

      Element.find('input[type=radio][name=registered]').on :change do |event|
        if event.element.value == 'registered'
          hide_element('#password-confirmation-field')
        elsif event.element.value == 'notregistered'
          show_element('#password-confirmation-field')
        end
      end
    end

    def sign_in
      #HTTP.post("/users/sign_in?user=") do |response|
        #if response.ok?
          #alert "successful!"
        #else
          #alert "request failed :("
        #end
      #end
    end

    def sign_up
      email = Element.find('#sign_up_modal .email').value
      password = Element.find('#sign_up_modal .password').value
      password_confirmation = Element.find('#sign_up_modal .password-confirmation').value

      HTTP.post("/users", payload: {user: {email: email, password: password, password_confirmation: password_confirmation}}, headers: HEADERS) do |response|
        if response.ok?
          alert "User created!"
        else
          alert "Errors: #{response.json}"
        end
      end
    end

    def show_modal(class_or_id)
      Element.find(class_or_id).add_class 'is-active'
    end

    def hide_modal(class_or_id)
      Element.find(class_or_id).remove_class 'is-active'
    end

    def show_element(class_or_id)
      Element.find(class_or_id).remove_class 'is-hidden'
    end

    def hide_element(class_or_id)
      Element.find(class_or_id).add_class 'is-hidden'
    end
  end

  class Editor
    def initialize(dom_id, options)
      @native = `CodeMirror(document.getElementById(dom_id), #{options.to_n})`
    end

    def value=(str)
      `#@native.setValue(str)`
    end

    def value
      `#@native.getValue()`
    end
  end

  def self.instance
    @instance ||= self.new
  end

  def initialize
    @flush = []

    @output = Editor.new :output, lineNumbers: false, mode: 'text', readOnly: true
    @editor = Editor.new :editor, lineNumbers: true, mode: 'ruby', tabMode: 'shift', theme: 'tomorrow-night-eighties', extraKeys: {
      'Cmd-Enter' => -> { run_code }
    }

    @link = Element.find('#link_code')
    @user_actions = UserActions.new

    Element.find('#run_code').on(:click) { run_code }
    Element.find('#stop').on(:click) { Negasonic::Time.stop }

    hash = `decodeURIComponent(location.hash || location.search)`

    if hash =~ /^[#?]code:/
      @editor.value = hash[6..-1]
		else
			@editor.value = DEFAULT_TRY_CODE.strip
    end
  end

  def start_negasonic
    if Tone::Transport.stopped?
      %x{
        StartAudioContext(Tone.context).then(function(){
          Tone.Master.volume.value = -20;
          #{Tone::Transport.start('+0.1')}
        })
      }

      Negasonic::Time.set_cycle_number_acummulator
    end
  end

  def run_code
    start_negasonic

    @flush = []
    @output.value = ''

    set_link_code

    begin
      Negasonic::Instrument.set_all_to_not_used

      Negasonic.default_instrument.store_current_cycles
      Negasonic.default_instrument.reload

      code = Opal.compile(@editor.value, :source_map_enabled => false)
      eval_code code

      Negasonic.default_instrument.stored_cycles.each(&:dispose)
      Negasonic.default_instrument.cycles.each(&:start)

      Negasonic::Time.schedule_next_cycle do
        Negasonic::Instrument.all_not_used.each(&:kill_current_cycles)
      end

      Negasonic::Time.just_started = false
    rescue => err
      log_error err
    end
  end

  def set_link_code
    @link[:href] = "?code:#{`encodeURIComponent(#{@editor.value})`}"
  end

  def eval_code(js_code)
    `eval(js_code)`
  end

  def log_error(err)
    puts "#{err}\n#{`err.stack`}"
  end

  def print_to_output(str)
    @flush << str
    @output.value = @flush.join('')
  end
end

Document.ready? do
  $stdout.write_proc = $stderr.write_proc = proc do |str|
    TryNegasonic.instance.print_to_output(str)
  end
  TryNegasonic.instance.set_link_code
end
