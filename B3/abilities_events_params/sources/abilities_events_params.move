module abilities_events_params::abilities_events_params;

use std::string::String;
use sui::event;

//Error Codes
const EMedalNotFound: u64 = 111;

// Structs

public struct Hero has key {
    id: UID, // required
    name: String,
    medals: vector<Medal>,
}

public struct HeroRegistry has key, store {
    id: UID,
    heroes: vector<ID>,
}

public struct Medal has key, store {
    id: UID,
    name: String,
}

public struct MedalStorage has key, store {
    id: UID,
    medals: vector<Medal>,
}

public struct HeroMinted has copy, drop {
    hero: ID,
    owner: address,
}

// Module Initializer
fun init(ctx: &mut TxContext) {
    let registry = HeroRegistry {
        id: object::new(ctx),
        heroes: vector[],
    };

    let mut medal_storage = MedalStorage {
        id: object::new(ctx),
        medals: vector[],
    };

    let medal1 = Medal {
        id: object::new(ctx),
        name: b"Accra Medal".to_string(),
    };
    let medal2 = Medal {
        id: object::new(ctx),
        name: b"Medal of Honor".to_string(),
    };
    let medal3 = Medal {
        id: object::new(ctx),
        name: b"Military Medal".to_string(),
    };

    medal_storage.medals.push_back((medal1));
    medal_storage.medals.push_back((medal2));
    medal_storage.medals.push_back((medal3));

    transfer::share_object(registry);
    transfer::share_object(medal_storage);
}

public fun mint_hero(name: String, hero_registry: &mut HeroRegistry, ctx: &mut TxContext): Hero {
    let freshHero = Hero {
        id: object::new(ctx), // creates a new UID
        name,
        medals: vector[],
    };

    let hero_id = object::id(&freshHero);

    hero_registry.heroes.push_back(hero_id);

    event::emit(HeroMinted {
        hero: hero_id,
        owner: ctx.sender(),
    });

    freshHero
}

public fun mint_and_keep_hero(name: String, hero_registry: &mut HeroRegistry, ctx: &mut TxContext) {
    let hero = mint_hero(name, hero_registry, ctx);
    transfer::transfer(hero, ctx.sender());
}

public fun award_accra_medal(hero: &mut Hero, medal_storage: &mut MedalStorage) {
    award_medal(hero, medal_storage, b"Accra Medal".to_string());
}

public fun award_medal_of_honor(hero: &mut Hero, medal_storage: &mut MedalStorage) {
    award_medal(hero, medal_storage, b"Medal of Honor".to_string());
}

public fun award_military_medal(hero: &mut Hero, medal_storage: &mut MedalStorage) {
    award_medal(hero, medal_storage, b"Military Medal".to_string());
}

// INTERNAL FUNCTION
fun award_medal(hero: &mut Hero, medal_storage: &mut MedalStorage, medal_name: String) {
    let medal_option: Option<Medal> = get_medal(medal_name, medal_storage);

    assert!(medal_option.is_some(), EMedalNotFound);

    hero.medals.append(medal_option.to_vec());
}

fun get_medal(medalName: String, medalStorage: &mut MedalStorage): Option<Medal> {
    let mut i = 0;
    let max = medalStorage.medals.length();

    while (i < max) {
        if (medalStorage.medals[i].name == medalName) {
            let extractedMedal = vector::remove(&mut medalStorage.medals, i);
            return option::some(extractedMedal)
        };

        i = i + 1;
    };

    option::none()
}

/////// Tests ///////

#[test_only]
use sui::test_scenario as ts;
#[test_only]
use sui::test_scenario::{take_shared, return_shared};
#[test_only]
use sui::test_utils::{destroy};
#[test_only]
use std::unit_test::assert_eq;

//--------------------------------------------------------------
//  Test 1: Hero Creation
//--------------------------------------------------------------
//  Objective: Verify the correct creation of a Hero object.
//  Tasks:
//      1. Complete the test by calling the `mint_hero` function with a hero name.
//      2. Assert that the created Hero's name matches the provided name.
//      3. Properly clean up the created Hero object using `destroy`.
//--------------------------------------------------------------
#[test]
fun test_hero_creation() {
    let mut test = ts::begin(@USER);
    init(test.ctx());
    test.next_tx(@USER);

    //Get hero Registry
    let mut registry = take_shared<HeroRegistry>(&test);

    let hero = mint_hero(
        b"Flash".to_string(),
        &mut registry,
        test.ctx(),
    );

    assert!(hero.name == b"Flash".to_string(), 101);

    destroy(hero);
    return_shared(registry);
    test.end();
}

//--------------------------------------------------------------
//  Test 2: Event Emission
//--------------------------------------------------------------
//  Objective: Implement event emission during hero creation and verify its correctness.
//  Tasks:
//      1. Define a `HeroMinted` event struct with appropriate fields (e.g., hero ID, owner address).  Remember to add `copy, drop` abilities!
//      2. Emit the `HeroMinted` event within the `mint_hero` function after creating the Hero.
//      3. In this test, capture emitted events using `event::events_by_type<HeroMinted>()`.
//      4. Assert that the number of emitted `HeroMinted` events is 1.
//      5. Assert that the `owner` field of the emitted event matches the expected address (e.g., @USER).
//--------------------------------------------------------------
#[test]
fun test_event_thrown() {
    let mut scenario = ts::begin(@USER);

    init(scenario.ctx());
    scenario.next_tx(@USER);

    let mut registry = take_shared<HeroRegistry>(&scenario);
    let hero = mint_hero(b"Flash".to_string(), &mut registry, scenario.ctx());
    let hero2 = mint_hero(b"Batman".to_string(), &mut registry, scenario.ctx());
    assert!(hero.name == b"Flash".to_string(), 201);
    assert!(hero2.name == b"Batman".to_string(), 202);

    let events: vector<HeroMinted> = event::events_by_type<HeroMinted>();
    assert!(events.length() == 2, 203);

    let mut i = 0;
    while (i < events.length()) {
        assert!(events[i].owner == @USER, 204);
        i = i + 1;
    };

    destroy(hero);
    destroy(hero2);

    return_shared(registry);

    scenario.end();
}

//--------------------------------------------------------------
//  Test 3: Medal Awarding
//--------------------------------------------------------------
//  Objective: Implement medal awarding functionality to heroes and verify its effects.
//  Tasks:
//      1. Define a `Medal` struct with appropriate fields (e.g., medal ID, medal name). Remember to add `key, store` abilities!
//      2. Add a `medals: vector<Medal>` field to the `Hero` struct to store the medals a hero has earned.
//      3. Create functions to award medals to heroes, e.g., `award_medal_of_honor(hero: &mut Hero)`.
//      4. In this test, mint a hero.
//      5. Award a specific medal (e.g., Medal of Honor) to the hero using your `award_medal_of_honor` function.
//      6. Assert that the hero's `medals` vector now contains the awarded medal.
//      7. Consider creating a shared `MedalStorage` object to manage the available medals.
//--------------------------------------------------------------
#[test]
fun test_medal_award() {
    let mut scenario = ts::begin(@USER);

    // init contract
    init(scenario.ctx());
    scenario.next_tx(@USER);

    // take shared objects
    let mut registry = take_shared<HeroRegistry>(&scenario);
    let mut medal_storage = take_shared<MedalStorage>(&scenario);

    // mint hero
    let mut hero = mint_hero(b"Kostas".to_string(), &mut registry, scenario.ctx());

    award_accra_medal(&mut hero, &mut medal_storage);
    assert!(hero.medals.length() == 1, 301);

    award_medal_of_honor(&mut hero, &mut medal_storage);
    assert!(hero.medals.length() == 2, 302);

    return_shared(registry);
    return_shared(medal_storage);

    destroy(hero);

    scenario.end();
}
