class CompiledJS < Hyperloop::Component
  param :html

  render do
    params.html.render
  end
end

class RenderComponent < Hyperloop::Component
  param :component_name
  param :random_key

  before_update { @errors = false }

  after_error do |error, info|
    puts "error = #{error}"
    puts "info = #{info}"
    @errors = true
   end

  render do
    begin
      React.create_element( Module.const_get(params.component_name), {key: params.random_key}) unless @errors
    rescue Exception => e
      puts "caught it but cant do anything about it"
      puts "error = #{e.message}"
    end
  end
end

class LiveCodeSegment < Hyperloop::Component
  param :content
  param :code

  before_mount do
    mutate.ruby_code params.code
  end

  render(DIV, class: 'block') do
    Sem.Divider(hidden: true)

    Sem.Grid(columns: 2, relaxed: true, padded: false, container: false) do
      Sem.GridColumn(width: 4, className: 'tight-box') { params.content }
      Sem.GridColumn(width: 12) do
        Sem.Container(className: 'white-background outline-box') do
          tab
        end
      end
    end
  end

  def code_editor_and_results
    Sem.Grid(columns: 2, relaxed: false, padded: false, container: true) do
      Sem.GridColumn(width: 12, className: 'tight-box') { code_mirror_editor }
      Sem.GridColumn(width: 4) do
        unless compile && evaluate && render_component
          Sem.Message(negative: true) do
            H3 { state.compile_error_heading }
            P { state.compile_error_message }
          end
        end
      end
    end
  end

  def tab
    live_code = code_editor_and_results.as_node
    compiled_js = CompiledJS(html: opal_code_html.as_node).as_node

    panes = []
    panes.concat [ { menuItem: 'Live Ruby',   render: -> { live_code.to_n } },
                   { menuItem: 'JavaScript', render: -> { compiled_js.to_n } }
    ]
    menu = { secondary: false, pointing: true }
    Sem.Tab(menu: menu.to_n, panes: panes.to_n )
  end

  def code_mirror_editor
    options = {
      lineNumbers: false,
      mode: :ruby,
      theme: 'one-dark',
      indentUnit: 2,
      matchBrackets: true
    }
    ReactCodeMirror(options: options.to_n, value: state.ruby_code.to_n, onChange: lambda { |value| mutate.ruby_code value })
  end

  def opal_code_html
    if @compiled_code
      html_code = `hljs.highlightAuto(#{@compiled_code}).value`
      PRE(class: 'code pre-md-code') do
        CODE(class: 'lang-javascript hljs small-code-font') do
           DIV( dangerously_set_inner_HTML: { __html: html_code } )
         end
      end
    else
      Sem.Message(negative: true) do
        H3 { state.compile_error_heading }
        P { state.compile_error_message }
      end
    end
  end

  def compile
    begin
      @compiled_code = nil
      @compiled_code = Opal::Compiler.new(state.ruby_code).compile
    rescue Exception => e
      mutate.compile_error_heading "Compile error"
      mutate.compile_error_message e.message
      return false
    end
    true
  end

  def evaluate
    begin
      `eval(#{@compiled_code})`
    rescue Exception => e
      @compiled_code = nil
      mutate.compile_error_heading "Evaluation error"
      mutate.compile_error_message e.message
      return false
    end
    true
  end

  def render_component
    begin
      DIV(id: 'result') do
        RenderComponent(component_name: component_name, random_key: rand(2**256).to_s(36)[0..7])
      end
    rescue Exception => e
      mutate.compile_error_heading "Invalid component error"
      mutate.compile_error_message e.message
      return false
    end
    true
  end

  def component_name
    elements = state.ruby_code.split ' '
    elements[ (elements.index('Hyperloop::Component') -2) ]
  end

end
