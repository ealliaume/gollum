require File.join(File.dirname(__FILE__), *%w[helper])

context "Markup" do
  setup do
    @path = testpath("examples/test.git")
    FileUtils.rm_rf(@path)
    Grit::Repo.init_bare(@path)
    @wiki = Gollum::Wiki.new(@path)

    @commit = { :message => "Add stuff",
                :name => "Tom Preston-Werner",
                :email => "tom@github.com" }
  end

  teardown do
    FileUtils.rm_r(File.join(File.dirname(__FILE__), *%w[examples test.git]))
  end

  test "double page links no space" do
    @wiki.write_page("Bilbo Baggins", :markdown, "a [[Foo]][[Bar]] b", @commit)

    page = @wiki.page("Bilbo Baggins")
    assert_equal "<p>a <a class=\"internal absent\" href=\"/Foo\">Foo</a><a class=\"internal absent\" href=\"/Bar\">Bar</a> b</p>", page.formatted_data
  end

  test "double page links with space" do
    @wiki.write_page("Bilbo Baggins", :markdown, "a [[Foo]] [[Bar]] b", @commit)

    page = @wiki.page("Bilbo Baggins")
    assert_equal "<p>a <a class=\"internal absent\" href=\"/Foo\">Foo</a> <a class=\"internal absent\" href=\"/Bar\">Bar</a> b</p>", page.formatted_data
  end

  test "page link" do
    @wiki.write_page("Bilbo Baggins", :markdown, "a [[Bilbo Baggins]] b", @commit)

    page = @wiki.page("Bilbo Baggins")
    output = page.formatted_data
    assert_match /class="internal present"/, output
    assert_match /href="\/Bilbo-Baggins"/,   output
    assert_match /\>Bilbo Baggins\</,        output
  end

  test "absent page link" do
    @wiki.write_page("Tolkien", :markdown, "a [[J. R. R. Tolkien]]'s b", @commit)

    page = @wiki.page("Tolkien")
    output = page.formatted_data
    assert_match /class="internal absent"/,         output
    assert_match /href="\/J\.\-R\.\-R\.\-Tolkien"/, output
    assert_match /\>J\. R\. R\. Tolkien\</,         output
  end

  test "page link with custom base path" do
    ["/wiki", "/wiki/"].each do |path|
      @wiki = Gollum::Wiki.new(@path, :base_path => path)
      @wiki.write_page("Bilbo Baggins", :markdown, "a [[Bilbo Baggins]] b", @commit)

      page = @wiki.page("Bilbo Baggins")
      output = page.formatted_data
      assert_match /class="internal present"/,     output
      assert_match /href="\/wiki\/Bilbo-Baggins"/, output
      assert_match /\>Bilbo Baggins\</,            output
    end
  end

  test "image with http url" do
    ['http', 'https'].each do |scheme|
      @wiki.write_page("Bilbo Baggins", :markdown, "a [[#{scheme}://example.com/bilbo.jpg]] b", @commit)

      page = @wiki.page("Bilbo Baggins")
      output = page.formatted_data
      assert_equal %{<p>a <img src="#{scheme}://example.com/bilbo.jpg" /> b</p>}, output
    end
  end

  test "image with absolute path" do
    @wiki = Gollum::Wiki.new(@path, :base_path => '/wiki')
    index = @wiki.repo.index
    index.add("alpha.jpg", "hi")
    index.commit("Add alpha.jpg")
    @wiki.write_page("Bilbo Baggins", :markdown, "a [[/alpha.jpg]] [[a | /alpha.jpg]] b", @commit)

    page = @wiki.page("Bilbo Baggins")
    assert_equal %{<p>a <img src="/wiki/alpha.jpg" /><a href="/wiki/alpha.jpg">a</a> b</p>}, page.formatted_data
  end

  test "image with relative path on root" do
    @wiki = Gollum::Wiki.new(@path, :base_path => '/wiki')
    index = @wiki.repo.index
    index.add("alpha.jpg", "hi")
    index.add("Bilbo-Baggins.md", "a [[alpha.jpg]] [[a | alpha.jpg]] b")
    index.commit("Add alpha.jpg")

    page = @wiki.page("Bilbo Baggins")
    assert_equal %{<p>a <img src="/wiki/alpha.jpg" /><a href="/wiki/alpha.jpg">a</a> b</p>}, page.formatted_data
  end

  test "image with relative path" do
    @wiki = Gollum::Wiki.new(@path, :base_path => '/wiki')
    index = @wiki.repo.index
    index.add("greek/alpha.jpg", "hi")
    index.add("greek/Bilbo-Baggins.md", "a [[alpha.jpg]] [[a | alpha.jpg]] b")
    index.commit("Add alpha.jpg")

    page = @wiki.page("Bilbo Baggins")
    output = page.formatted_data
    assert_equal %{<p>a <img src="/wiki/greek/alpha.jpg" /><a href="/wiki/greek/alpha.jpg">a</a> b</p>}, output
  end

  test "image with alt" do
    content = "a [[alpha.jpg|alt=Alpha Dog]] b"
    output = %{<p>a <img src="/greek/alpha.jpg" alt="Alpha Dog" /> b</p>}
    relative_image(content, output)
  end

  test "image with em or px dimension" do
    %w{em px}.each do |unit|
      %w{width height}.each do |dim|
        content = "a [[alpha.jpg|#{dim}=100#{unit}]] b"
        output = "<p>a <img src=\"/greek/alpha.jpg\" #{dim}=\"100#{unit}\" /> b</p>"
        relative_image(content, output)
      end
    end
  end

  test "image with bogus dimension" do
    %w{width height}.each do |dim|
      content = "a [[alpha.jpg|#{dim}=100]] b"
      output = "<p>a <img src=\"/greek/alpha.jpg\" /> b</p>"
      relative_image(content, output)
    end
  end

  test "image with vertical align" do
    %w{top texttop middle absmiddle bottom absbottom baseline}.each do |align|
      content = "a [[alpha.jpg|align=#{align}]] b"
      output = "<p>a <img src=\"/greek/alpha.jpg\" align=\"#{align}\" /> b</p>"
      relative_image(content, output)
    end
  end

  test "image with horizontal align" do
    %w{left center right}.each do |align|
      content = "a [[alpha.jpg|align=#{align}]] b"
      output = "<p>a <span class=\"align-#{align}\"><span><img src=\"/greek/alpha.jpg\" /></span></span> b</p>"
      relative_image(content, output)
    end
  end

  test "image with float" do
    content = "a\n\n[[alpha.jpg|float]]\n\nb"
    output = "<p>a</p>\n\n<p><span class=\"float-left\"><span><img src=\"/greek/alpha.jpg\" /></span></span></p>\n\n<p>b</p>"
    relative_image(content, output)
  end

  test "image with float and align" do
    %w{left right}.each do |align|
      content = "a\n\n[[alpha.jpg|float|align=#{align}]]\n\nb"
      output = "<p>a</p>\n\n<p><span class=\"float-#{align}\"><span><img src=\"/greek/alpha.jpg\" /></span></span></p>\n\n<p>b</p>"
      relative_image(content, output)
    end
  end

  test "image with frame" do
    content = "a\n\n[[alpha.jpg|frame]]\n\nb"
    output = "<p>a</p>\n\n<p><span class=\"frame\"><span><img src=\"/greek/alpha.jpg\" /></span></span></p>\n\n<p>b</p>"
    relative_image(content, output)
  end

  test "image with frame and alt" do
    content = "a\n\n[[alpha.jpg|frame|alt=Alpha]]\n\nb"
    output = "<p>a</p>\n\n<p><span class=\"frame\"><span><img src=\"/greek/alpha.jpg\" alt=\"Alpha\" /><span>Alpha</span></span></span></p>\n\n<p>b</p>"
    relative_image(content, output)
  end

  test "file link with absolute path" do
    index = @wiki.repo.index
    index.add("alpha.jpg", "hi")
    index.commit("Add alpha.jpg")
    @wiki.write_page("Bilbo Baggins", :markdown, "a [[Alpha|/alpha.jpg]] b", @commit)

    page = @wiki.page("Bilbo Baggins")
    output = Gollum::Markup.new(page).render
    assert_equal %{<p>a <a href="/alpha.jpg">Alpha</a> b</p>}, output
  end

  test "file link with relative path" do
    index = @wiki.repo.index
    index.add("greek/alpha.jpg", "hi")
    index.add("greek/Bilbo-Baggins.md", "a [[Alpha|alpha.jpg]] b")
    index.commit("Add alpha.jpg")

    page = @wiki.page("Bilbo Baggins")
    output = Gollum::Markup.new(page).render
    assert_equal %{<p>a <a href="/greek/alpha.jpg">Alpha</a> b</p>}, output
  end

  test "file link with external path" do
    index = @wiki.repo.index
    index.add("greek/Bilbo-Baggins.md", "a [[Alpha|http://example.com/alpha.jpg]] b")
    index.commit("Add alpha.jpg")

    page = @wiki.page("Bilbo Baggins")
    assert_equal %{<p>a <a href="http://example.com/alpha.jpg">Alpha</a> b</p>}, page.formatted_data
  end

  test "code blocks" do
    content = "a\n\n```ruby\nx = 1\n```\n\nb"
    output = "<p>a</p>\n\n<div class=\"highlight\"><pre>" +
             "<span class=\"n\">x</span> <span class=\"o\">=</span> " +
             "<span class=\"mi\">1</span>\n</pre>\n</div>\n\n<p>b</p>"

    index = @wiki.repo.index
    index.add("Bilbo-Baggins.md", content)
    index.commit("Add alpha.jpg")

    page = @wiki.page("Bilbo Baggins")
    rendered = Gollum::Markup.new(page).render
    assert_equal output, rendered
  end

  test "code blocks with carriage returns" do
    content = "a\r\n\r\n```ruby\r\nx = 1\r\n```\r\n\r\nb"
    output = "<p>a</p>\n\n<div class=\"highlight\"><pre>" +
             "<span class=\"n\">x</span> <span class=\"o\">=</span> " +
             "<span class=\"mi\">1</span>\n</pre>\n</div>\n\n<p>b</p>"

    index = @wiki.repo.index
    index.add("Bilbo-Baggins.md", content)
    index.commit("Add alpha.jpg")

    page = @wiki.page("Bilbo Baggins")
    rendered = Gollum::Markup.new(page).render
    assert_equal output, rendered
  end

  test "escaped wiki link" do
    content = "a '[[Foo]], b"
    output = "<p>a [[Foo]], b</p>"
    compare(content, output)
  end

  test "quoted wiki link" do
    content = "a '[[Foo]]', b"
    output = "<p>a '<a class=\"internal absent\" href=\"/Foo\">Foo</a>', b</p>"
    compare(content, output, 'md', [
      /class="internal absent"/,
      /href="\/Foo"/,
      /\>Foo\</])
  end

  test "org mode style double links" do
    content = "a [[http://google.com][Google]] b"
    output = "<p class=\"title\">a <a href=\"http://google.com\">Google</a> b</p>"
    compare(content, output, 'org')
  end

  def compare(content, output, ext = "md", regexes = [])
    index = @wiki.repo.index
    index.add("Bilbo-Baggins.#{ext}", content)
    index.commit("Add baggins")

    page = @wiki.page("Bilbo Baggins")
    rendered = Gollum::Markup.new(page).render
    if regexes.empty?
      assert_equal output, rendered
    else
      regexes.each { |r| assert_match r, output }
    end
  end

  def relative_image(content, output)
    index = @wiki.repo.index
    index.add("greek/alpha.jpg", "hi")
    index.add("greek/Bilbo-Baggins.md", content)
    index.commit("Add alpha.jpg")

    page = @wiki.page("Bilbo Baggins")
    rendered = Gollum::Markup.new(page).render
    assert_equal output, rendered
  end
end