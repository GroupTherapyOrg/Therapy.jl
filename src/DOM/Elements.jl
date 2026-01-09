# Elements.jl - HTML element functions (Capitalized like JSX)

# Helper to create element function
function make_element(tag::Symbol)
    return function(args...; kwargs...)
        props, children = parse_element_args(args...; kwargs...)
        VNode(tag, props, children)
    end
end

# Layout elements
const Div = make_element(:div)
const Span = make_element(:span)
const P = make_element(:p)
const Br = make_element(:br)
const Hr = make_element(:hr)

# Text elements
const H1 = make_element(:h1)
const H2 = make_element(:h2)
const H3 = make_element(:h3)
const H4 = make_element(:h4)
const H5 = make_element(:h5)
const H6 = make_element(:h6)
const Strong = make_element(:strong)
const Em = make_element(:em)
const Code = make_element(:code)
const Pre = make_element(:pre)
const Blockquote = make_element(:blockquote)

# Links and media
const A = make_element(:a)
const Img = make_element(:img)
const Video = make_element(:video)
const Audio = make_element(:audio)
const Source = make_element(:source)
const Iframe = make_element(:iframe)

# Form elements
const Form = make_element(:form)
const Input = make_element(:input)
const Button = make_element(:button)
const Textarea = make_element(:textarea)
const Select = make_element(:select)
const Option = make_element(:option)
const Label = make_element(:label)
const Fieldset = make_element(:fieldset)
const Legend = make_element(:legend)

# List elements
const Ul = make_element(:ul)
const Ol = make_element(:ol)
const Li = make_element(:li)
const Dl = make_element(:dl)
const Dt = make_element(:dt)
const Dd = make_element(:dd)

# Table elements
const Table = make_element(:table)
const Thead = make_element(:thead)
const Tbody = make_element(:tbody)
const Tfoot = make_element(:tfoot)
const Tr = make_element(:tr)
const Th = make_element(:th)
const Td = make_element(:td)
const Caption = make_element(:caption)

# Semantic elements
const Header = make_element(:header)
const Footer = make_element(:footer)
const Nav = make_element(:nav)
const MainEl = make_element(:main)  # Named MainEl to avoid conflict with Julia's Main module
const Section = make_element(:section)
const Article = make_element(:article)
const Aside = make_element(:aside)
const Details = make_element(:details)
const Summary = make_element(:summary)
const Figure = make_element(:figure)
const Figcaption = make_element(:figcaption)

# Script and style (use underscore prefix to avoid conflicts)
const Script = make_element(:script)
const Style = make_element(:style)
const Link = make_element(:link)
const Meta = make_element(:meta)

# SVG elements
const Svg = make_element(:svg)
const Path = make_element(:path)
const Circle = make_element(:circle)
const Rect = make_element(:rect)
const Line = make_element(:line)
const Polygon = make_element(:polygon)
const Polyline = make_element(:polyline)
const Text = make_element(:text)
const G = make_element(:g)
const Defs = make_element(:defs)
const Use = make_element(:use)
