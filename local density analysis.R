# =======================================================

# the distance_matrix function finds the difference from each point to every other point, 
# and returns a rectangular matrix (which means each distance is in the matrix twice, 
# once from point A to point B, and again from point B to point A)

distance_matrix <- function(location_data = locations, x = 1, y = 2){
  as.matrix(stats::dist(x = location_data[,c(x,y)], method = "euclidean")) 
}

# =======================================================

# local_counts is a function to find the counts of points of different types within the 
# local neighborhood of each point -- points are included in the counts 
# of their own neighborhood. The output is a dataframe that includes the point location 
# and type of each point, as well as counts (by type) of points within the 
# specified radius of each point.

local_counts <- function(location_data = locations, radius){

  distance <- distance_matrix(location_data = location_data)
  output <- location_data
  output$radius <- radius
  
  # find the counts for artifacts of each type in the neighborhood of each point
  type_list <- sort(unique(location_data$type))
  num_types <- length(type_list)
  neighbor_counts_per_type <- lapply(type_list, function(current_type) {
    is_current_type <- locations$type == current_type
    apply(distance, 1, function(one_row) {
      relevant_neighbors <- one_row[is_current_type]
      sum(relevant_neighbors <= radius)
    })
  })

  # find the total count of neighboring artifacts
  total_neighbour_count <- apply(distance, 1, function(one_row) {
    sum(one_row <= radius)
  })
    
  output <- cbind(output, neighbor_counts_per_type)
  colnames(output)[(ncol(output)-num_types+1):ncol(output)] <- paste0("count_", as.character(type_list))
  output$count_total <- total_neighbour_count

  return(output)
}


# =======================================================
# local_density is a function that calls the local_count function, 
# then calculates the area of the neighborhood defined by the specified 
# radius. The local_density is the count divided by the area of the 
# neighborhood. The function outputs a dataframe that includes the point 
# location and type of each point, as well as the density of points of 
# each type within the specified radius of each point.


local_density <- function(location_data = locations, radius) {
  counts <- local_counts(location_data, radius)
  local_densities <- counts
  type_list <- unique(local_densities$type)
  type_list <- sort(type_list)
  
  # reduce the same-type counts and the total counts for 
  # each point by 1 so that points don't count in calculating their
  # own local densities
  for (i in 1:nrow(local_densities)) {
    local_densities[i,ncol(local_densities)] <- local_densities[i,ncol(local_densities)] - 1
    for (j in 1:length(type_list))
    if (local_densities$type[i] == type_list[j]) {
      local_densities[i,j + 4] <- local_densities[i,j + 4] - 1
    }
  }
  
  area <- pi * radius^2
  col_list <- colnames(local_densities)
  for (i in 5:ncol(local_densities)) {
    col_list[i] <- substring(col_list[i],7)
    col_list[i] <- paste0("density_", col_list[i])
    for (j in 1:nrow(local_densities)) {
      local_densities[j,i] <- local_densities[j,i] / area
    }
  }
 colnames(local_densities) <- col_list 
  
 return(local_densities)  

}



# =======================================================
# glb_density calculates the global density of points of each type 
# (the number of points of the type divided by the total area) 
# and returns a vector of the global densities that gets used by the lda function
#to calculate the local density coefficient

glb_density <- function(location_data = locations, site_area) {
  type_list <- unique(location_data$type)
  type_list <- sort(type_list)
  global_density <- matrix(nrow = length(type_list) + 1)
  for (i in 1:length(type_list)) {
    temp <- filter(location_data, type == type_list[i])
    global_density[i] <- nrow(temp) / site_area
  }
  global_density[length(type_list) + 1] <- nrow(location_data) / site_area
  row.names(global_density) <- c(type_list, "total")
  return(global_density)
}


# =======================================================
#lda calculates the local density coefficient within and between 
# all the types in the dataset. The local density coefficient from Type A 
# to Type B is the mean density of points of Type B within the specified 
# radius of points of Type A, divided by the global density of points of 
# Type B (i.e., the number of points of Type B divided by the total area)

lda <- function(location_data = locations, radius, site_area) {
  for (n in 1:length(radius)) {
    densities <- local_density(location_data, radius[n])
    type_list <- unique(location_data$type)
    type_list <- sort(type_list)
    global_density <- glb_density(location_data, site_area)
    lda_matrix <- matrix(nrow = length(type_list) + 1, ncol = length(type_list) + 2)
    name_list <- c(as.character(type_list), "total")
    name_list_col <- c(paste0("ldc_", name_list), "radius")
    colnames(lda_matrix) <- name_list_col

      for (i in 1:(length(type_list) + 1)) {
      if (i <= length(type_list)){
        current_type <- filter(densities, type == type_list[i])
        for (j in 1:(length(type_list) + 1)) {
         lda_matrix[i,j] <- round(mean(current_type[,j + 4]) / global_density[j], 2)
        }
      }
      else {
        for (j in 1:(length(type_list) + 1)) {
          lda_matrix[(length(type_list) + 1),j] <- mean(densities[,j + 4]) / global_density[j]
        }
      }
      
    }
    lda_matrix <- as.data.frame(round(lda_matrix, 2))
    type <- name_list
    lda_matrix <- cbind(type, lda_matrix)
    lda_matrix$radius <- radius[n]
    if (n == 1) {
      lda_out <- lda_matrix
    }
    else {
      lda_out <- rbind(lda_out, lda_matrix)
    }
  }

  return(lda_out)
}


# =======================================================

#code to test out the functions above with two example data files


#some functions use mutate() from the dplyr package
library(dplyr)


# the data should be formatted as a data frame of artifact locations
# with x coordinates in the first column, y coordinates in the second, and artifact type
# in the third column

locations <- read.csv(file = file.choose())
# this just ensures that the column names in the data file are consistent
colnames(locations) <- c("x", "y", "type")


distance_test <- distance_matrix(location_data = locations)

counts_test <- local_counts(radius = 2)

local_density_test <- local_density(radius = 2)

#site area for Kintigh's example file "LDEN.csv = 154"
#the site area for "AZ_A1020_BLM_point_plots.csv" = 2409

global_density_test <- glb_density(site_area = 2409)

lda_test <- lda(locations, radius = 2, site_area = 154)

#test with multiple radii
lda_test <- lda(locations, radius = cbind(1, 2, 3, 4, 5, 6, 7, 8, 9 , 10), site_area = 2409)




