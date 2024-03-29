#Derived from map.market from the portfolio package, by 
# Jeff Enos and David Kane, with contributions from 
# Daniel Gerlanc and Kyle Campbell
# http://cran.r-project.org/web/packages/portfolio/index.html

# better-treemap is by David Wilkins <david@wilkox.org>
# it lives at https://github.com/wilkox/better-treemap

#This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

flow.text.to.box <- function(thetext, thewidth) {

  textregex = as.character(cat("(.{", thewidth, "}[^ ]+) "))

  thetext = gsub("(.{8}[^ ]+) ", "\\1\n",thetext,perl=TRUE)
  return(thetext)
  
}

better.treemap <- function(id, area, group, color,
                       scale = NULL,
                       lab   = c(TRUE, FALSE),
                       main  = "Map of the Market",
                       print = TRUE
                       ){

  if(any(length(id) != length(area),
         length(id) != length(group),
         length(id) != length(color))){
    stop("id, area, group, and color must be the same length.")
  }

  ## If only one logical given for "lab", use for both group and stock
  ## labels
  
  if(length(lab) == 1){
    lab[2] <- lab[1]
  }

  ## NA values in the id parameter are not allowed.

  stopifnot(all(!is.na(id)))

  ## Collect the input vectors in a data.frame.
  
  data <- data.frame(label = id, group, area, color)
  data <- data[order(data$area, decreasing = TRUE),]

  ## area, group and color need to be non-NA for a record to be
  ## included in the viz.

  if(any(is.na(data$area) | is.na(data$group) | is.na(data$color))){
    warning("Stocks with NAs for area, group, or color will not be shown")
    data <- subset(data, !is.na(area) & !is.na(group) & !is.na(color))
  }

  ## If no records pass the above criteria, stop.

  if(nrow(data) == 0){
    stop("No records to display")
  }
  
  ## If no color divisor is specified, map the values in 'color' to
  ## the interval [0,1], maintaining spacing.  Otherwise, divide by
  ## the supplied scaling factor.

  data$color.orig <- data$color
  
  if(is.null(scale)){
    data$color <- data$color * 1/max(abs(data$color))
  }
  else{
    data$color <- sapply(data$color, function(x) {if(x/scale > 1) 1 else if(-1 > x/scale) -1 else x/scale})
  }
  
  ## Start dividing data up into groups.
  
  data.by.group <- split(data, data$group, drop = TRUE)

  group.data <- lapply(data.by.group, function(x){sum(x[,3])})
  group.data <- data.frame(area  = as.numeric(group.data),
                           label = names(group.data))
  group.data <- group.data[order(group.data$area, decreasing=TRUE),]
  group.data$color <- rep(NULL, nrow(group.data))

  ## Two color gradient functions to map [-1,0] to [red, black] and
  ## [0,1] to [black, green].
  
  color.ramp.pos <- colorRamp(c("white", "#FFBFBF", bias=2))
  color.ramp.neg <- colorRamp(c("white", "#9F9FFF", bias=12))

  ## Map a vector with values in [-1,1] to a vector of rgb colors.
  
  color.ramp.rgb <- function(x){
    col.mat <- mapply(
                      function(x){
                        if(x < 0){
                          color.ramp.neg(abs(x))
                        }
                        else{
                          color.ramp.pos(abs(x))
                        }
                      },
                      x)
    mapply(rgb, col.mat[1,], col.mat[2,], col.mat[3,], max = 255)
  }
  
  ## Accepts the current viewport list and parameters for the next viewport
  ## Returns the viewport list with the next viewport appended to it.

  add.viewport <- function(z, label, color, x.0, y.0, x.1, y.1){
  
    for(i in 1:length(label)){

      ## Groups are transparent, positive change is green, negative
      ## change is red.

      if(is.null(color[i])){
        filler <- gpar(col="blue", fill="transparent", cex = 1)
      }
      else{
        filler.col <- color.ramp.rgb(color[i])
        filler <- gpar(col = filler.col, fill = filler.col, cex = 0.6)
      }
      
      ## Viewport created from squarified treemap specifications

      new.viewport <- viewport(x = x.0[i],
                               y = y.0[i],
                               width  = (x.1[i] - x.0[i]),
                               height = (y.1[i] - y.0[i]),
                               default.units = "npc",
                               just = c("left", "bottom"),
                               name = as.character(label[i]),
                               clip = "on", gp = filler)
      
      z <- append(z, list(new.viewport))
    }
    z
  }

  ## Recursive function that returns a complete list of viewports, in
  ## the order they should be plotted.  "z" should be a data frame
  ## with columns "area", "label", and "color", sorted in descending
  ## order by "z$area"; "viewport.list" should be an initially empty
  ## list; func should be the "add.viewport" function defined above

  squarified.treemap <- function(z, x = 0, y = 0, w = 1, h = 1,
                                 func = add.viewport, viewport.list){

    ## "cz" stores cumulative percentages of the total area
    
    cz <- cumsum(z$area) / sum(z$area)

    ## "n" marks where to break this region

    n <- which.min(abs(log(max(w/h, h/w) * sum(z$area) * ((cz^2)/z$area))))
    
    ## do we have any left-over rectangles?

    more <- n < length(z$area)

    ## "a" stores cumulative percentages for this region

    a <- c(0, cz[1:n]) / cz[n]
    
    ## Determines the direction in which we are adding rectangles

    if (h > w){

      ## Calls the add.viewport function n times, adding each
      ## rectangle to "viewport.list"

      viewport.list <- func(viewport.list, z$label[1:n], z$color[1:n],
                            x+w*a[1:(length(a)-1)], rep(y,n), x+w*a[-1],
                            rep(y+h*cz[n],n))

      ## Recursive call, in case there are more regions

      if(more){
        viewport.list <- Recall(z[-(1:n), ], x, y+h*cz[n], w, h*(1-cz[n]),
                                func, viewport.list)
      }
    }
    else{
      viewport.list <- func(viewport.list, z$label[1:n], z$color[1:n],
                            rep(x,n), y+h*a[1:(length(a)-1)],
                            rep(x+w*cz[n],n), y+h*a[-1])
      
      if(more){
        viewport.list <- Recall(z[-(1:n), ], x+w*cz[n], y, w*(1-cz[n]),
                                h, func, viewport.list)
      }
    }
    
    viewport.list

  }

  ## Create gTree representing the actual map of the market

  map.viewport <- viewport(x = 0.05, y = 0.05, width = 0.9, height = 0.75, clip = "inherit",
                           default.units = "npc", name = "MAP",
                           just = c("left", "bottom"))
  
  map.tree <- gTree(vp = map.viewport, name = "MAP",
                  children = gList(rectGrob(gp = gpar(col = "dark grey"),
                    name = "background")))
  
  ## Get viewports for each group
  
  group.viewports <- squarified.treemap(z = group.data,
                                         viewport.list = list())

  ## For each group, create gTree for the group and get viewports for
  ## the stocks in that group.

  for(i in 1:length(group.viewports)){
     
    this.group <- data.by.group[[group.data$label[i]]]
    this.data <- data.frame(this.group$area, this.group$label,
                            this.group$color)
    names(this.data) <- c("area", "label", "color")
    
    stock.viewports <- squarified.treemap(z = this.data, viewport.list = list())

    group.tree <- gTree(vp = group.viewports[[i]], name = group.data$label[i])

    ## For each stock in the current group, create a gTree and add it
    ## to the group gTree
    
    for(s in 1:length(stock.viewports)){
      stock.tree <- gTree(vp = stock.viewports[[s]], name = this.data$label[s],
                         children = gList(rectGrob(name = "color")))
      
      if(lab[2]){
        name = toString(this.data$label[s])
        output = gsub(" ", "\n", name)
        splitname = strsplit(name, " ")
        for (hello in splitname) {
            namelengths = nchar(hello)
        }
        longest = max(namelengths)

        ##get rectangle width
        rectwidth = stock.viewports[[s]]$width
        rectwidth = gsub("npc", "", rectwidth, perl=TRUE)
        rectwidth = as.numeric(rectwidth)
        rectwidth = rectwidth * 100
        widthfactor = (rectwidth / longest) / 0.55

        ##get rectangle height
        rectheight = stock.viewports[[s]]$height
        rectheight = gsub("npc", "", rectheight, perl=TRUE)
        rectheight = as.numeric(rectheight)
        rectheight = rectheight * 100
        heightfactor = (rectheight / length(namelengths)) / 0.4

        #the smallest factor becomes the cex, to fit in the rectangle
        textfactor = min(c(heightfactor, widthfactor))
        print(c("Textfactor is " , textfactor))

        stock.tree <- addGrob(stock.tree, textGrob(
                                                   ##THIS IS WHERE THE LABELS ARE MADE
                                                   x = unit(0.1, "lines"), y = unit(1, "npc") - unit(0.1, "lines"),
                                                   label = output,
                                                   gp = gpar(col = "black", fontsize="10"),
                                                   name = "label",
                                                   just = c("left", "top")
                                                   ))
      } 

      group.tree <- addGrob(group.tree, stock.tree)
    }    

    ## Add border and label grobs to group gTree
    
    group.tree <- addGrob(group.tree, rectGrob(gp = gpar(col = "grey"),
                                               name = "border"))
    
    if(lab[1]){
      group.tree <- addGrob(group.tree, textGrob(label = flow.text.to.box(toString(group.data$label[i]), 6), just=c("left", "bottom"), x=0.02, y=0.02,
                                                  name = "label", gp = gpar(col = "black", fontface = "bold")))
    }

    ## Add group gTree to map gTree
    
    map.tree <- addGrob(map.tree, group.tree)
  }
  
  ## Create gTree to represent top

  op <- options(digits = 1)
  
  top.viewport <- viewport(x = 0.05, y = 1, width = 0.9, height = 0.20,
                           default.units = "npc", name = "TOP",,
                           just = c("left", "top"))

  legend.ncols <- 51
  l.x <- (0:(legend.ncols-1))/(legend.ncols)
  l.y <- unit(0.25, "npc")
  l.cols <- color.ramp.rgb(seq(-1, 1, by = 2/(legend.ncols-1)))
 
  if(is.null(scale)){
    l.end <- max(abs(data$color.orig))
  }
  else{
    l.end <- scale
  }
  
  top.list <-
    gList(textGrob(label = main, y = unit(0.7, "npc"),
                   just = c("left", "bottom"), gp = gpar(cex = 2)),
          
          segmentsGrob(x0 = seq(0, 1, by = 0.25), y0 = unit(0.25, "npc"),
                       x1 = seq(0, 1, by = 0.25), y1 = unit(0.2, "npc")),
          
          rectGrob(x = l.x, y = l.y,
                   width = 1/legend.ncols, height = unit(1, "lines"),
                   just  = c("left","bottom"),
                   gp    = gpar(col = NA, fill = l.cols),
                   default.units = "npc"),
          
          textGrob(label = format(l.end * seq(-1, 1, by = 0.5), trim = TRUE),
                   x = seq(0, 1, by = 0.25), y = 0.1,
                   default.units = "npc",
                   just = c("left", "bottom"),
                   gp = gpar(col = "black", cex = 0.8, fontface = "bold")))
                   
  options(op)
  
  top.tree <- gTree(vp = top.viewport, name = "TOP",
                       children = top.list)

  ## Put map and top gTrees together
  
  mapmarket <- gTree(name = "MAPMARKET", children = gList(
                                           rectGrob(gp=gpar(col="white",
                                                      fill="white"),
                                                    name = "background"),
                                           top.tree,
                                           map.tree
                                           ))

  ## Print and return

  if(print){
    grid.newpage()
    grid.draw(mapmarket)
  }
  
  invisible(mapmarket)
}
