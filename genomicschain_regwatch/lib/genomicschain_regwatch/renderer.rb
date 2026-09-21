# frozen_string_literal: true

require 'json'
require 'time'

module GenomicsChainRegwatch
  # Renders a scan result as one standalone HTML file, in English or Japanese.
  #
  # Standalone because the audience for this is a person opening a file, not a
  # server. No external CSS, no fonts, no scripts beyond a theme toggle — a
  # report that needs a network to render is a report that stops rendering.
  #
  # The palette is the validated data-visualisation default (light and dark
  # steps of the same hues, not an automatic flip). Status is never carried by
  # colour alone: every chip pairs a glyph and a word with its colour, because
  # the light-mode warning and serious steps sit below 3:1 by design.
  class Renderer
    STRINGS = {
      'en' => {
        title: 'Regulatory &amp; Standards Watch',
        subtitle: 'GenomicsChain / KairosChain',
        scanned: 'Scanned', rules: 'Rules', baseline: 'Baseline',
        never: 'never recorded', items: 'items',
        partial: 'Partial pass: %{examined} of %{total} watched sources were examined. ' \
                 'The rest were not looked at, and nothing here says anything about them.',
        h_deadlines: 'Dated triggers', h_findings: 'Watched sources',
        h_warnings: 'Watchlist warnings', h_limits: 'What this scan cannot see',
        col_due: 'Due', col_days: 'Days', col_what: 'What', col_binds: 'Binds',
        col_source: 'Source', col_status: 'Status', col_note: 'Note',
        overdue: 'overdue', today: 'today',
        st_changed: 'changed', st_unchanged: 'unchanged',
        st_unreachable: 'unreachable', st_new: 'new', st_not_checked: 'not checked',
        none_due: 'No dated trigger inside the horizon.',
        stale: 'Baseline was written under different scan rules — digests are not comparable. Re-record.',
        judge: 'This tool reports. It does not rule on whether a change is material — ' \
               'that judgement belongs to the operator, and is recorded separately.',
        offline: 'Offline pass: nothing was fetched and no digest was compared.'
      },
      'ja' => {
        title: '規制・標準の動向監視',
        subtitle: 'GenomicsChain / KairosChain',
        scanned: '走査日時', rules: '規則版', baseline: '基準値',
        never: '未記録', items: '件',
        partial: '一部走査: 監視対象 %{total} 件のうち %{examined} 件のみを調べた。' \
                 '残りは見ていない。この報告は残りについて何も述べていない。',
        h_deadlines: '期日のある事項', h_findings: '監視している資料',
        h_warnings: '監視表の警告', h_limits: 'この走査が見られないもの',
        col_due: '期日', col_days: '残り', col_what: '内容', col_binds: '拘束する相手',
        col_source: '資料', col_status: '状態', col_note: '備考',
        overdue: '超過', today: '本日',
        st_changed: '変化', st_unchanged: '変化なし',
        st_unreachable: '到達不能', st_new: '新規', st_not_checked: '未確認',
        none_due: '対象期間内に期日のある事項はない。',
        stale: '基準値が別の走査規則の下で記録されている。digest は比較できない。記録し直すこと。',
        judge: 'この道具は報告する。変化が重要かどうかの判断はしない —— ' \
               'その判断は運用者のものであり、別に記録される。',
        offline: 'オフライン走査: 取得も digest の比較も行っていない。'
      }
    }.freeze

    STATUS_STYLE = {
      'changed' => { css: 'c-crit', glyph: '●' },
      'unreachable' => { css: 'c-serious', glyph: '▲' },
      'new' => { css: 'c-warn', glyph: '＋' },
      'not_checked' => { css: 'c-muted', glyph: '–' },
      'unchanged' => { css: 'c-good', glyph: '✓' }
    }.freeze

    # changed and unreachable are shown even at zero — seeing that they are
    # zero is the point of opening the report. The rest appear only when they
    # have something in them.
    ALWAYS_SHOWN = %w[changed unreachable].freeze
    TILE_ORDER = %w[changed unreachable new not_checked unchanged].freeze

    def initialize(scan_result, lang: 'en')
      @r = scan_result
      @lang = STRINGS.key?(lang) ? lang : 'en'
      @t = STRINGS[@lang]
    end

    def render
      +<<~HTML
        <!DOCTYPE html>
        <html lang="#{@lang}" data-theme="light">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>#{@t[:title]} — #{@r['scanned_at']}</title>
        <style>#{css}</style>
        </head>
        <body>
        <button class="toggle" id="tt" aria-label="theme">◐</button>
        <div class="wrap">
        #{masthead}
        #{counts}
        #{deadlines}
        #{findings}
        #{warnings}
        #{limits}
        <footer><p>#{@t[:judge]}</p>
        <p class="mono">genomicschain_regwatch #{VERSION} · #{@r['rules_version']}</p></footer>
        </div>
        <script>
        (function(){var b=document.getElementById('tt'),r=document.documentElement;
        b.addEventListener('click',function(){var c=r.getAttribute('data-theme');
        r.setAttribute('data-theme', c==='dark'?'light':'dark');});})();
        </script>
        </body>
        </html>
      HTML
    end

    private

    def h(s)
      s.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;')
    end

    def masthead
      b = @r['baseline'] || {}
      stale = b['stale_rules'] ? %(<p class="alert">#{@t[:stale]}</p>) : ''
      off = @r['offline'] ? %(<p class="alert">#{@t[:offline]}</p>) : ''

      # A narrowed scan (`only:`) produced a report indistinguishable from a
      # full sweep: the counts tiles add up to whatever was examined, and
      # nothing said the rest had not been looked at. On a page meant for
      # publication that is the same failure as scoring a blocked source as a
      # pass — a partial check reading as a complete one.
      examined = @r['examined'].to_i
      total = @r['watchlist_items'].to_i
      partial = if total.positive? && examined < total
                  fmt = @t[:partial].sub('%{examined}', examined.to_s).sub('%{total}', total.to_s)
                  %(<p class="alert">#{fmt}</p>)
                else
                  ''
                end
      <<~HTML
        <header>
          <h1>#{@t[:title]}</h1>
          <p class="sub">#{@t[:subtitle]} &middot;
            #{@t[:scanned]} <span class="mono">#{h(@r['scanned_at'])}</span> &middot;
            #{@t[:baseline]} <span class="mono">#{h(b['recorded_at'] || @t[:never])}</span>
            (#{b['entries'].to_i} #{@t[:items]})</p>
          #{partial}#{stale}#{off}
        </header>
      HTML
    end

    def counts
      c = @r['counts'] || {}
      tiles = TILE_ORDER.select { |s| c[s].to_i.positive? || ALWAYS_SHOWN.include?(s) }.map do |s|
        st = STATUS_STYLE[s]
        %(<div class="tile"><div class="v #{st[:css]}">#{c[s].to_i}</div>
           <div class="k">#{st[:glyph]} #{@t[:"st_#{s}"]}</div></div>)
      end.join
      %(<div class="tiles">#{tiles}</div>)
    end

    def deadlines
      rows = (@r['deadlines'] || []).map do |d|
        days = d['days_remaining'].to_i
        label = if days.negative? then %(<span class="c-crit">#{days.abs} #{@t[:overdue]}</span>)
                elsif days.zero? then %(<span class="c-crit">#{@t[:today]}</span>)
                elsif days <= 30 then %(<span class="c-serious">#{days}</span>)
                else days.to_s
                end
        <<~ROW
          <tr><td class="mono nowrap">#{h(d['due'])}</td><td class="num">#{label}</td>
          <td><strong>#{h(d['title'])}</strong>#{d['why'] ? %(<div class="why">#{h(d['why'])}</div>) : ''}</td>
          <td class="muted">#{h(d['binds'])}</td></tr>
        ROW
      end.join

      body = rows.empty? ? %(<p class="muted">#{@t[:none_due]}</p>) : <<~T
        <table><thead><tr><th>#{@t[:col_due]}</th><th class="num">#{@t[:col_days]}</th>
        <th>#{@t[:col_what]}</th><th>#{@t[:col_binds]}</th></tr></thead><tbody>#{rows}</tbody></table>
      T
      %(<h2>#{@t[:h_deadlines]}</h2>#{body})
    end

    def findings
      order = TILE_ORDER.each_with_index.to_h
      rows = (@r['findings'] || []).sort_by { |f| [order.fetch(f['status'], 9), f['id'].to_s] }.map do |f|
        st = STATUS_STYLE[f['status']] || { css: '', glyph: '·' }
        link = f['url'] ? %(<a href="#{h(f['url'])}">#{h(f['id'])}</a>) : h(f['id'])
        note = [f['reason'], f['excerpt'] && %(<span class="mono ex">#{h(f['excerpt'])}</span>)].compact.join('<br>')
        <<~ROW
          <tr><td>#{link}<div class="why">#{h(f['title'])}</div></td>
          <td class="nowrap"><span class="chip #{st[:css]}">#{st[:glyph]} #{@t[:"st_#{f['status']}"]}</span></td>
          <td class="muted small">#{note}</td></tr>
        ROW
      end.join
      %(<h2>#{@t[:h_findings]}</h2><table><thead><tr><th>#{@t[:col_source]}</th>
        <th>#{@t[:col_status]}</th><th>#{@t[:col_note]}</th></tr></thead><tbody>#{rows}</tbody></table>)
    end

    def warnings
      w = @r['watchlist_warnings'] || []
      return '' if w.empty?
      %(<h2>#{@t[:h_warnings]}</h2><ul class="muted">#{w.map { |x| "<li>#{h(x)}</li>" }.join}</ul>)
    end

    def limits
      l = @r['limits'] || []
      return '' if l.empty?
      %(<h2>#{@t[:h_limits]}</h2><ul class="muted">#{l.map { |x| "<li>#{h(x)}</li>" }.join}</ul>)
    end

    def css
      <<~CSS
        :root{color-scheme:light;--surface:#fcfcfb;--page:#f9f9f7;--ink:#0b0b0b;--ink2:#52514e;
          --muted:#898781;--grid:#e1e0d9;--axis:#c3c2b7;--border:rgba(11,11,11,.10);
          --good:#0ca30c;--warn:#8a6100;--serious:#a3502a;--crit:#d03b3b;--s1:#2a78d6}
        :root[data-theme=dark]{color-scheme:dark;--surface:#1a1a19;--page:#0d0d0d;--ink:#fff;--ink2:#c3c2b7;
          --muted:#898781;--grid:#2c2c2a;--axis:#383835;--border:rgba(255,255,255,.10);
          --good:#0ca30c;--warn:#fab219;--serious:#ec835a;--crit:#d03b3b;--s1:#3987e5}
        @media(prefers-color-scheme:dark){:root:where(:not([data-theme=light])){color-scheme:dark;
          --surface:#1a1a19;--page:#0d0d0d;--ink:#fff;--ink2:#c3c2b7;--grid:#2c2c2a;--axis:#383835;
          --border:rgba(255,255,255,.10);--warn:#fab219;--serious:#ec835a;--s1:#3987e5}}
        *{box-sizing:border-box}
        body{margin:0;padding:0 0 4rem;background:var(--page);color:var(--ink);
          font-family:system-ui,-apple-system,"Hiragino Sans","Noto Sans JP","Segoe UI",sans-serif;
          font-size:15px;line-height:1.7}
        .wrap{max-width:940px;margin:0 auto;padding:0 1.4rem}
        header{border-bottom:1px solid var(--border);padding:2.2rem 0 1.2rem;margin-bottom:1.6rem}
        h1{font-size:1.5rem;margin:0 0 .35rem}
        h2{font-size:1.08rem;margin:2.4rem 0 .5rem;padding-top:1.1rem;border-top:1px solid var(--border)}
        .sub{color:var(--ink2);font-size:.88rem;margin:0}
        .alert{margin:.7rem 0 0;padding:.5rem .8rem;border-left:3px solid var(--crit);
          background:var(--surface);border-radius:0 6px 6px 0;font-size:.87rem}
        .tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:.7rem;margin:1.2rem 0}
        .tile{background:var(--surface);border:1px solid var(--border);border-radius:9px;padding:.8rem .9rem}
        .tile .v{font-size:1.7rem;font-weight:650;line-height:1.1}
        .tile .k{font-size:.8rem;color:var(--ink2);margin-top:.15rem}
        table{border-collapse:collapse;width:100%;margin:.9rem 0;font-size:.88rem}
        th,td{text-align:left;padding:.5rem .6rem;border-bottom:1px solid var(--grid);vertical-align:top}
        th{color:var(--ink2);font-weight:600;font-size:.78rem;letter-spacing:.03em;border-bottom:1px solid var(--axis)}
        td.num,th.num{text-align:right;font-variant-numeric:tabular-nums}
        tbody tr:last-child td{border-bottom:none}
        .chip{display:inline-flex;gap:.28rem;align-items:center;font-size:.78rem;font-weight:600;
          padding:.08rem .48rem;border-radius:999px;border:1px solid currentColor;white-space:nowrap}
        .c-good{color:var(--good)}.c-warn{color:var(--warn)}.c-serious{color:var(--serious)}
        .c-crit{color:var(--crit)}.c-muted{color:var(--muted)}
        .why{font-size:.82rem;color:var(--ink2);margin-top:.15rem;line-height:1.6}
        .muted{color:var(--ink2)}.small{font-size:.82rem}.nowrap{white-space:nowrap}
        .mono{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.85em}
        .ex{display:block;margin-top:.3rem;color:var(--muted);word-break:break-word}
        a{color:var(--s1)}
        ul.muted{padding-left:1.1rem}
        ul.muted li{margin:.3rem 0;font-size:.87rem}
        footer{margin-top:2.6rem;padding-top:1rem;border-top:1px solid var(--border);
          font-size:.82rem;color:var(--muted)}
        .toggle{position:fixed;top:.9rem;right:.9rem;background:var(--surface);color:var(--ink2);
          border:1px solid var(--border);border-radius:999px;padding:.3rem .7rem;font-size:.8rem;cursor:pointer}
      CSS
    end
  end
end
