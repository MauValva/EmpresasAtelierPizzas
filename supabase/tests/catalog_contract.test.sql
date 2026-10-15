-- Executar com `supabase test db` após aplicar as migrations.
begin;
select plan(8);
select has_table('public', 'products');
select has_table('public', 'product_variants');
select has_table('public', 'recipes');
select has_table('public', 'recipe_versions');
select has_table('public', 'recipe_version_ingredients');
select has_table('public', 'promotions');
select has_table('public', 'promotion_eligible_variants');
select has_function('public', 'publish_recipe_version');
select * from finish();
rollback;
