import Foundation

/// Word lists used by the Random Generator tools.
enum RandomWordLists {
    private static func list(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init)
    }

    /// Common English words of many lengths (for the Random Word Generator).
    static let words: [String] = list("""
    able acid aged also area army away baby back ball band bank base bath bear beat bell belt best bird blue boat body bone book
    born boss both bowl bulk burn bush busy cafe cake call calm camp card care case cash cast cell chat chip city clay clip club
    coal coat code cold come cook cool copy corn cost crew crop dark data date dawn deal dear deep deer desk dial diet dish dive
    door dose down draw drop drum dust duty each earn ease east easy edge else even ever face fact fair fall farm fast fate fear
    feed feel fern file fill film find fine fire firm fish five flag flat flow foam fold folk food foot form fort four free from
    fuel full fund gain game gate gift girl give glad glow goal gold golf good gown grab gray grew grid grin grow gulf hair half
    hall hand hard harm hate have head heat help herb hero hill hint hold hole holy home hope horn host hour huge hunt idea inch
    iron isle item jazz join joke jump june jury just keen keep kind king knee knot lake lamp land lane last late lawn lead leaf
    lean left lend less life lift like lily line link lion list live load loan lock loft long look loop lord lost loud love luck
    lung made mail main make mall many maps mark mask mass mate meal mean meat meet melt menu mice mild mile milk mind mine mint
    miss mist mode mole moon more moss most move much must myth nail name navy near neck need nest news next nice nine node none
    noon nose note oath ocean odds once only open oral orbit oven over pace pack page pain pair palm park part past path peak pear
    pine pink pipe plan play plot plug plus poem poet pole pond pool poor port pose post pour pray pull pure push quit race rack
    rail rain rank rare rate read real rest rice rich ride ring rise risk road rock role roll roof room root rope rose rule rush
    safe sage sail salt same sand save seal seat seed seek self sell send shed ship shop shot show shut sick side sign silk sing
    site size skin slim slip slow snow soap soft soil sold solo some song soon sort soul soup spot star stay stem step stop such
    suit sure swan swim tail take tale talk tall tank tape task team tear tell tent term test text than then thin tide tile time
    tiny tire toad told tone tool tour town tree trim trip true tube tune turn twin type unit upon urban used user vale vast very
    view vine visit vital voice void vote wade wage wait wake walk wall want warm wash wave weak wear week well west what when
    whom wide wife wild will wind wine wing wire wise wish wolf wood wool word work worm wrap yard yarn year zero zone
    anchor animal answer apple arrow basket beach berry bottle branch bridge bright butter camera candle canyon carpet castle
    cattle chair change cherry circle cloud coffee copper corner cotton crystal desert dinner doctor dragon eagle engine fabric
    falcon farmer finger flower forest friend garden ginger glass golden guitar hammer harbor island jacket jungle kitchen ladder
    lantern leather lemon letter library marble meadow melody mirror morning mountain nature needle orange orchard pencil pepper
    pillow planet pocket pumpkin rabbit rainbow river rocket saddle school shadow silver simple spirit spring summer sunset
    thunder ticket tomato travel valley velvet village violin window winter wonder yellow
    adventure beautiful blossom champion chocolate classroom community computer creative daylight discovery elephant equipment
    fireplace footprint fortunate gathering happiness harmony horizon important invention kangaroo lighthouse magnificent
    marketplace melodies moonlight mysterious neighbour notebook orchestra paintbrush passenger peaceful pineapple playground
    porcelain quicksilver raspberry reflection sandcastle snowflake spaceship strawberry sunflower telescope thousand treasure
    umbrella universe waterfall wilderness wonderland
    """)

    static let adjectives: [String] = list("""
    brave bright calm clever cosmic crisp daring eager fancy fierce gentle giant golden happy humble jolly keen lively lucky
    mellow mighty misty modern nimble noble plucky proud quick quiet rapid rustic shiny silent silver sleek smooth snappy
    solar spicy steady stormy sunny swift tidy tiny vivid warm wild wise witty zesty amber azure coral crimson electric
    emerald frosty glossy ivory lunar magic neon orange purple scarlet velvet
    """)

    static let nouns: [String] = list("""
    badger beacon breeze bridge canyon comet condor coyote dolphin dragon eagle ember falcon fox galaxy garden glacier harbor
    hawk heron island jaguar jungle koala lagoon lantern lynx maple meadow meteor moose nebula ocean orbit otter owl panda
    panther pebble phoenix pilot planet puffin quartz rabbit raven river rocket sailor shadow sparrow spirit summit thunder
    tiger tundra valley voyager walrus willow wizard wolf yeti zephyr
    """)

    static let firstNames: [String] = list("""
    Aiden Amelia Andrew Aria Benjamin Camila Charlotte Chloe Daniel David Diego Elena Elijah Emma Ethan Eva Felix Grace Hannah
    Harper Henry Isabella Isaac Jack James Julia Kai Layla Leo Liam Lily Lucas Luna Maya Mia Mila Nathan Noah Nora Olivia Owen
    Priya Rohan Ruby Samuel Sofia Sophie Theo Victoria William Zoe
    """)

    static let lastNames: [String] = list("""
    Adams Allen Anderson Baker Bennett Brooks Brown Campbell Carter Clark Collins Cooper Davis Edwards Evans Fisher Foster
    Garcia Gray Green Hall Harris Hayes Hughes Jackson James Johnson Jones Kelly King Lee Lewis Martin Miller Mitchell Moore
    Morgan Murphy Nelson Parker Patel Phillips Reed Roberts Scott Smith Taylor Thomas Turner Walker Ward White Williams Wilson
    Wright Young
    """)

    /// Latin-style words for filler text.
    static let latin: [String] = list("""
    lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua
    enim ad minim veniam quis nostrud exercitation ullamco laboris nisi aliquip ex ea commodo consequat duis aute irure in
    reprehenderit voluptate velit esse cillum eu fugiat nulla pariatur excepteur sint occaecat cupidatat non proident sunt
    culpa qui officia deserunt mollit anim id est laborum perspiciatis unde omnis iste natus error voluptatem accusantium
    doloremque laudantium totam rem aperiam eaque ipsa quae ab illo inventore veritatis quasi architecto beatae vitae dicta
    explicabo nemo ipsam quia voluptas aspernatur odit aut fugit consequuntur magni dolores eos ratione sequi nesciunt neque
    porro quisquam dolorem adipisci numquam eius modi tempora incidunt magnam quaerat
    """)
}
