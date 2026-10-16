-- Generates docs/samples/structured_sample.parquet: a tiny table mixing flat
-- columns with nested types, to show how Duck Viewer renders each kind.
--   STRUCT        -> expanded into grouped sub-columns (up to the nesting depth)
--   STRUCT(STRUCT)-> two levels of grouped headers
--   LIST / MAP / STRUCT[] -> kept as a single cell, rendered as JSON
-- Regenerate from the repo root:  duckdb < docs/samples/structured_sample.sql
COPY (
  SELECT * FROM (VALUES
    (1, 'Ada Lovelace', TRUE,  DATE '2024-01-15', 129.90,
     {'city': 'London', 'zip': 'EC1A', 'geo': {'lat': 51.5072, 'lon': -0.1276}},
     ['math', 'poetry'],
     [{'sku': 'BK-001', 'qty': 2, 'price': 19.95}, {'sku': 'PN-010', 'qty': 1, 'price': 90.00}],
     MAP {'theme': 'dark', 'lang': 'en'}),
    (2, 'Alan Turing',  FALSE, DATE '2024-02-03', 54.00,
     {'city': 'Manchester', 'zip': 'M1', 'geo': {'lat': 53.4808, 'lon': -2.2426}},
     ['crypto'],
     [{'sku': 'CH-200', 'qty': 3, 'price': 18.00}],
     MAP {'lang': 'en'}),
    (3, 'Grace Hopper', TRUE,  DATE '2024-03-21', 0.00,
     {'city': 'New York', 'zip': '10001', 'geo': {'lat': 40.7128, 'lon': -74.0060}},
     [],
     [],
     MAP {'theme': 'light', 'lang': 'en', 'beta': 'yes'}),
    (4, 'Edsger Dijkstra', NULL, DATE '2024-04-08', 310.25,
     {'city': 'Rotterdam', 'zip': NULL, 'geo': NULL},
     ['graphs', 'semaphores', 'shortest-path'],
     [{'sku': 'BK-002', 'qty': 1, 'price': 310.25}],
     NULL),
    (5, 'Barbara Liskov', FALSE, DATE '2024-05-30', 72.40,
     NULL,
     NULL,
     [{'sku': 'BK-003', 'qty': 4, 'price': 18.10}],
     MAP {'theme': 'dark'})
  ) AS t(id, name, is_active, signup_date, total_spent,
         address, tags, orders, preferences)
) TO 'docs/samples/structured_sample.parquet' (FORMAT parquet);
