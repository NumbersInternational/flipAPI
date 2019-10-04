library (testthat)

test_that("SaveData/LoadData", {
  skip_if(!nzchar(companySecret), "Not in test environment or no company set up")

  # RDS
  expect_invisible(QSaveData(mtcars, "mtcars.rds"))
  expect_true(QFileExists("mtcars.rds"))
  
  rds <- QLoadData("mtcars.rds")
  expect_equivalent(mtcars, rds)
})

test_that("Save/Load Data: bad cases", {
  skip_if(!nzchar(companySecret), "Not in test environment or no company set up")
  
  # Bad cases
  bad_name <- "anamethatdoesnotexistfortesting"
  expect_warning(expect_false(QFileExists(bad_name)))
  expect_error(QLoadData(bad_name))
  expect_error(QSaveData(mtcars,"mtcars.notrds"))
})

test_that("File Connection: raw", {
  skip_if(!nzchar(companySecret), "Not in test environment or no company set up")
  
  # Test various file formats 
  # raw file
  filename <- "raw_test"
  expect_silent(conn <- QFileOpen(filename, "w"))
  txt_string <- "This is a test line."
  
  writeLines(txt_string, conn)
  expect_message(expect_invisible(close(conn)))
  
  expect_silent(conn <- QFileOpen(filename))
  expect_silent(read_lines <- readLines(conn, warn = FALSE))
  expect_equal(txt_string, read_lines)
  
  expect_silent(expect_invisible(close(conn)))
})

test_that("File Connection: rds", {
  skip_if(!nzchar(companySecret), "Not in test environment or no company set up")
  
  # csv file
  filename <- "test.rds"
  
  expect_silent(conn <- QFileOpen(filename, "w"))
  
  expect_silent(saveRDS(mtcars, conn, ascii = TRUE))
  expect_message(expect_invisible(close(conn)))
  
  expect_silent(conn <- QFileOpen(filename))
  expect_silent(csv <- readRDS(gzcon(conn)))
  
  expect_silent(expect_invisible(close(conn)))
})

test_that("File Connection: csv", {
  skip_if(!nzchar(companySecret), "Not in test environment or no company set up")
  
  # csv file
  filename <- "test.csv"
  
  expect_silent(conn <- QFileOpen(filename, "w"))
  
  expect_silent(write.csv(mtcars, conn))
  expect_message(expect_invisible(close(conn)))
  
  expect_silent(conn <- QFileOpen(filename))
  expect_silent(csv <- read.csv(conn))
  
  expect_silent(expect_invisible(close(conn)))
})

test_that("File Connection: json", {
  skip_if(!nzchar(companySecret), "Not in test environment or no company set up")
  # json file 
  filename <- "test.json"
  
  expect_silent(conn <- QFileOpen(filename, "w"))
  
  expect_silent(writeLines(jsonlite::toJSON(mtcars), conn))
  expect_message(expect_invisible(close(conn)))
  
  expect_silent(conn <- QFileOpen(filename))
  expect_silent(json <- jsonlite::fromJSON(readLines(conn, warn = FALSE)))
  expect_equivalent(json, mtcars)
  
  expect_silent(expect_invisible(close(conn)))
})