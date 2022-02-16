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

declare function mom:cell-sig ($mom as map:map) {
    fn:string-join (( '[', map:get ($mom, '_column'), '=', fn:string(map:get ($mom, '_content')), ' (', fn:string (fn:count (map:get ($mom, '_kids'))), ')]' ), '')
};

declare function mom:result-to-mom ($config, $result) {
    (: init the root :)
    let $mom := mom:new-cell ('_root')
    let $_setup := map:put ($mom, '_config', $config)
    let $_setup := map:put ($mom, '_start', 1)
    let $columns := map:get ($config, 'columns')
    let $group := map:get ($config, 'group')

    let $_load := 
        (: for each row, start at the root map and add the cols/vals :)
        for $row in $result
        let $trace := xdmp:trace('mom:rtm', 'adding row '||xdmp:describe ($row, (), ()))
        let $values := for $column in $columns return (map:get ($row, $column))
        return mom:result-to-mom_ ($mom, $columns, $values, $group)
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
    let $new-string := fn:string-join (($column, $content), '=')
    let $trace := xdmp:trace('mom:rtm', 'checking '||$new-string||' vs latest '||$latest-string)
    return $latest-string = $new-string
};

declare function mom:latest-kid ($mom) {
    map:get ($mom, '_kids')[last()]
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

