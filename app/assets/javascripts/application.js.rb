require 'jquery'
require 'codemirror'
require 'ruby_codemirror'
require 'start_audio_context'

require 'opal'
require 'opal-parser'
require 'opal-jquery'
require 'negasonic'
require 'bowser/cookie'

# https://stackoverflow.com/questions/33941864/rails-automatically-update-csrf-token-for-repeat-json-request
%x{
  $( document ).ajaxComplete(function( event, xhr, settings ) {
    header_token = xhr.getResponseHeader('X-CSRF-Token');
    if (header_token) $('meta[name=csrf-token]').attr('content', header_token)
  });
}

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
    def initialize(editor: )
      @editor = editor
      @user_registered = false

      Element.find('#save').on(:click) do
        if signed_in?
          save_file
        else
          show_modal('#save_modal')
        end
      end
      Element.find('.cancel-save').on(:click) do
        hide_modal('#save_modal')
      end
      Element.find('#save_modal .is-success').on(:click) do
        if @user_registered
          sign_in(
            email: Element.find('#save_modal .email').value,
            password: Element.find('#save_modal .password').value,
            save_file: true
          )
        else
          sign_up(
            email: Element.find('#save_modal .email').value,
            password: Element.find('#save_modal .password').value,
            password_confirmation: Element.find('#save_modal .password-confirmation').value,
            save_file: true
          )
        end
      end

      Element.find('#open').on(:click) do
        show_modal('#open_modal')
      end
      Element.find('.cancel-open').on(:click) do
        hide_modal('#open_modal')
      end
      Element.find('#open_modal .is-success').on(:click) do
        sign_in(
          email: Element.find('#open_modal .email').value,
          password: Element.find('#open_modal .password').value
        )
      end
      Element.find('#sign_out').on(:click) do
        sign_out
      end

      Element.find('input[type=radio][name=registered]').on :change do |event|
        if event.element.value == 'registered'
          hide_element('#password-confirmation-field')
          @user_registered = true
        elsif event.element.value == 'notregistered'
          show_element('#password-confirmation-field')
          @user_registered = false
        end
      end

      if signed_in?
        hide_open_button
      else
        hide_sign_out_button
      end
    end

    def signed_in?
      cookie = Bowser::Cookie['user_signed_in']
      cookie && cookie.value == '1'
    end

    def csrf_token_headers
      {'X-CSRF-Token' => Element['meta[name=csrf-token]'].attr('content')}
    end

    def save_file
      HTTP.put("/track_files/update_current", payload: { file_text: @editor.value }, headers: csrf_token_headers) do |response|
        if response.ok?
          alert "file saved successfully!"
        else
          alert "#{response.json}"
        end
      end
    end

    def load_saved_file_in_editor
      HTTP.get("/track_files/show_current", payload: {}, headers: csrf_token_headers) do |response|
        if response.ok?
          @editor.value = response.json["file_text"]
        else
          alert "#{response.json}"
        end
      end
    end

    def sign_in(email: , password:, save_file: false)
      payload = {user: {email: email, password: password, remember_me: 1}}
      payload.merge!(file_text: @editor.value) if save_file

      HTTP.post("/users/sign_in", payload: payload, headers: csrf_token_headers) do |response|
        if response.ok?
          unless save_file
            @editor.value = response.json["file_text"]
          end
          hide_open_button
          show_sign_out_button
          if save_file
            hide_modal('#save_modal')
          else
            hide_modal('#open_modal')
          end

          alert "logged in successfull!"
        else
          alert "#{response.json}"
        end
      end
    end

    def sign_up(email: , password:, password_confirmation: ,save_file: false)
      payload = {user: {email: email, password: password, password_confirmation: password_confirmation, remember_me: 1}}
      payload.merge!(file_text: @editor.value) if save_file

      HTTP.post("/users", payload: payload, headers:  csrf_token_headers) do |response|
        if response.ok?
          hide_open_button
          show_sign_out_button
          if save_file
            hide_modal('#save_modal')
          else
            hide_modal('#open_modal')
          end

          alert "User created!"
        else
          alert "Errors: #{response.json}"
        end
      end
    end

    def sign_out
      HTTP.delete("/users/sign_out", headers: csrf_token_headers)
      hide_sign_out_button
      show_open_button
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

    def hide_sign_out_button
      Element.find('#sign_out').add_class 'is-hidden'
    end

    def show_sign_out_button
      Element.find('#sign_out').remove_class 'is-hidden'
    end

    def hide_open_button
      Element.find('#open').add_class 'is-hidden'
    end

    def show_open_button
      Element.find('#open').remove_class 'is-hidden'
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
    @user_actions = UserActions.new(editor: @editor)

    Element.find('#run_code').on(:click) { run_code }
    Element.find('#stop').on(:click) { Negasonic::Time.stop }

    hash = `decodeURIComponent(location.hash || location.search)`

    if hash =~ /^[#?]code:/
      @editor.value = hash[6..-1]
		else
      if @user_actions.signed_in?
        @user_actions.load_saved_file_in_editor
      else
        @editor.value = DEFAULT_TRY_CODE.strip
      end
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
