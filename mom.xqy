xquery version '1.0-ml';

module namespace mom = 'http://marklogic.com/support/map-of-maps';

(: ======= sql:result to mom stuff ======= :)


declare function mom:dump-mom ($mom) { mom:dump-mom ('', $mom) };

declare function mom:dump-mom ($indent, $mom) {
    let $attr :=
        for $key in map:keys ($mom) 
        where fn:not ($key = ('_column', '_content', '_kids', '_config'))
        return fn:concat ('(', $key, '=',  fn:string (map:get ($mom, $key)), ')')
    return 
        ('map-of-maps: '||$indent||map:get ($mom, '_column') ||' = '||map:get ($mom, '_content') || ' | ' || fn:string-join ($attr, ' '))
    ,
    for $kid in map:get ($mom, '_kids')
    return mom:dump-mom ($indent||'    ', $kid)
};

(: string dump of a cell :)
declare function mom:cell-sig ($mom as map:map) {
    fn:string-join (( '[', map:get ($mom, '_column'), '=', fn:string(map:get ($mom, '_content')),
        ' (', fn:string (fn:count (map:get ($mom, '_kids'))), '/', fn:string (map:get ($mom, '_start')), '+', fn:string (map:get ($mom, '_height')), ')]' ), '')
};

declare function mom:result-to-mom ($config, $result) {
    (: init the root :)
    let $mom := mom:new-cell ('_root')
    let $_setup := map:put ($mom, '_config', $config)
    let $_setup := map:put ($mom, '_start', 1)
    let $columns := map:get ($config, 'columns')
    let $group := (map:get ($config, 'group'), fn:true())[1]

    let $_load := 
        (: for each row, start at the root map and add the cols/vals :)
        for $row in $result
        let $trace := xdmp:trace('mom:rtm', 'adding row '||xdmp:describe ($row, (), ()))
        let $values := for $column in $columns return (map:get ($row, $column))
        return mom:result-to-mom_ ($mom, $columns, $values, $group)
    let $_ready_calculations := mom:transform ($config, $mom)
    let $_ready_calculations := mom:assign-heights ($mom)
    let $_ready_calculations := mom:assign-starts ($mom)
    return $mom
};

declare function mom:result-to-mom_ ($mom, $columns, $values, $group) {
    if (fn:count ($values) = 0 or fn:count ($columns) = 0) then () else (: end of recursion :)
    let $column := $columns[1]
    let $value := $values[1]
    let $trace := xdmp:trace('mom:rtm', 'adding '||$column||' = '||$value||'.')
    let $matches-current := mom:check-for-matching-kid ($mom, $column, $value)
    return
        if ($matches-current and $group) then
            (: implicit grouping; recurse into latest-kid, don't create a new one :)
            let $latest-kid := mom:latest-kid ($mom)
            let $trace := xdmp:trace('mom:rtm', 'moving to matched cell '||mom:cell-sig ($latest-kid))
            return mom:result-to-mom_ ($latest-kid, fn:subsequence ($columns, 2), fn:subsequence ($values, 2), $group)
        else
            (: create a new kid and add to the list :)
            let $new-kid := mom:add-kid ($mom, $column, $value)
            let $latest-kid := mom:latest-kid ($mom)
            let $trace := xdmp:trace('mom:rtm', 'adding cell '||mom:cell-sig ($new-kid)||' to '||mom:cell-sig ($mom)||', moving to '||mom:cell-sig ($latest-kid))
            return mom:result-to-mom_ ($latest-kid, fn:subsequence ($columns, 2), fn:subsequence ($values, 2), $group)
};

declare function mom:check-for-matching-kid ($mom, $column, $content) as xs:boolean {
    let $latest := mom:latest-kid ($mom)
    let $latest-string := fn:string-join ((map:get ($latest, '_column'), fn:string(map:get ($latest, '_content'))), '=')
    let $new-string := fn:string-join (($column, fn:string ($content)), '=')
    let $trace := xdmp:trace('mom:rtm', 'checking '||$new-string||' vs latest '||$latest-string)
    return $latest-string = $new-string
};

declare function mom:latest-kid ($mom) {
    map:get ($mom, '_kids')[last()]
};

declare function mom:kids ($mom) {
    map:get ($mom, '_kids')
};

declare function mom:add-kid ($mom, $column, $content) {
    let $new := mom:new-cell ($column, $content)
    let $_add := map:put ($mom, '_kids', (map:get ($mom, '_kids'), $new))
    return $new
};

declare function mom:new-cell ($column) {
    mom:new-cell ($column, (), ())
};

declare function mom:new-cell ($column, $content) {
    mom:new-cell ($column, $content, ())
};

declare function mom:new-cell ($column, $content, $kids) {
    map:new((
        map:entry ('_column', $column),
        map:entry ('_content', $content),
        map:entry ('_kids', $kids)
    ))
};


(: ======= mom to table stuff ======= :)

declare function mom:result-to-table ($config, $result) {
    let $trace := xdmp:trace('mom:table', 'working on table')
    let $mom := mom:result-to-mom ($config, $result)
    let $trace := xdmp:trace('mom:table', 'got mom '||mom:cell-sig ($mom))
    return mom:table ($mom)
};

(: recurse, assign heights and start rows :)
declare function mom:assign-heights ($root as map:map) {
    let $height :=
        if (map:count (map:get ($root, '_kids')) > 0) then
            fn:sum (for $kid in map:get ($root, '_kids') return mom:assign-heights ($kid))
        else 1
    let $_store := map:put ($root, '_height', $height) 
    return $height
};

(: recurse, assign heights and start rows :)
declare function mom:assign-starts ($root as map:map) {
    let $my-start := map:get ($root, '_start')
    let $offset := $my-start
    return
        for $kid in map:get ($root, '_kids')
        return (
            map:put ($kid, '_start', $offset),
            xdmp:set ($offset, $offset + map:get ($kid, '_height')),
            mom:assign-starts ($kid)
        )
};

(: here is where you get your table :)
declare function mom:table ($mom as map:map) {
    let $trace := xdmp:trace('mom:table', 'working on table for mom '||mom:cell-sig ($mom))
    let $config := map:get ($mom, '_config')
    let $caption := map:get ($config, 'caption')
    let $columns := map:get ($config, 'columns')
    return 
    <table border="1">{
        if ($caption) then <caption>{$caption}</caption> else (),
        <tr>{$columns ! <th>{.}</th>}</tr>,
        for $row in map:get ($mom, '_kids')
        return mom:table-row ($config, $row)
        }
    </table>
};

(: top level row call; you have to call once for each table row covered, and output any cells that start in that row :)
declare function mom:table-row ($config, $root) {
    let $start := map:get ($root, '_start') 
    let $height := map:get ($root, '_height') 
    for $row-num in $start to $start + $height - 1
    let $trace := xdmp:trace('mom:table', 'running row-num '||$row-num)
    return <tr>{mom:process-row-cells ($config, $root, $row-num)}</tr>
};

declare function mom:process-row-cells ($config, $root, $row-num) {
    let $start-row := map:get ($root, '_start') 
    let $height := map:get ($root, '_height') 
    let $last-row := $start-row + $height
    return (
        (: is this cell (and) the rest of this row out of scope for this row-num? :)
        if ($row-num < $start-row or $row-num > $start-row + $height - 1) then (
            xdmp:trace('mom:table', 'for row-num '||$row-num||' skipping '||mom:cell-sig ($root))
        ) else (
            xdmp:trace('mom:table', 'for row-num '||$row-num||' checking '||mom:cell-sig ($root)),
            if ($row-num eq $start-row) then (
                <td>{
                    attribute { 'rownum' } { $row-num },
                    if ($height > 1) then attribute { 'rowspan' } { $height } else (),
                    map:get ($root, '_content')
                }</td>
            ) else ()
            ,
            (map:get ($root, '_kids') ! mom:process-row-cells ($config, ., $row-num))
        )
    )
};

(: ============= transform mom =============== :)

(: transform should take ($config, $mom) 

   transform happens before cell calculations, so changes to structure are fine
 :)

declare function mom:transform ($config as map:map, $mom as map:map) {
    let $before := map:get ($config, 'before')
    let $after := map:get ($config, 'after')
    let $_before := xdmp:apply (map:get ($config, 'before'), $config, $mom)
    let $_under := 
        for $kid in mom:kids ($mom)
        return mom:transform ($config, $kid)
    let $_after := xdmp:apply (map:get ($config, 'after'), $config, $mom)
    return $mom
};


