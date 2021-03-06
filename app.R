
library(tidyverse)
library(ggplot2)
library(plotly)
library(shiny)
library(shinythemes)
library(DT)
theme_set(theme_minimal())
bu_data <- read_csv("data/bu.csv", guess_max = 1001)#, col_types = cols(level_difficulty = col_integer()))


dept <- bu_data %>% pull(tDept) %>% unique() %>% sort()


phy_prof <- bu_data %>% group_by(tDept, prof_name) %>% summarise(tDept, avg_rating=mean(rate_prof), avg_diff = mean(level_difficulty)) %>% unique()

phy_prof <- phy_prof %>% mutate_at(vars(avg_rating, avg_diff), funs(round(., 2)))

phy_prof2 <- phy_prof %>% mutate(overall_score = avg_rating + avg_diff) 

courses_rate <- bu_data %>% group_by(tDept, course_name) %>% summarise(course_name, avg_hw_lvl=mean(hw_level), avg_diff = mean(level_difficulty)) %>% unique()


#clean the course data
courses_rate <- courses_rate %>% mutate_at(vars(avg_hw_lvl, avg_diff), funs(round(., 2))) %>% filter(!is.na(avg_hw_lvl) & !is.na(avg_diff)) %>% filter(str_length(course_name) == 5)

courses_rate2 <- courses_rate %>% mutate(overall_score = avg_hw_lvl + avg_diff) 


#for each course, find the best rating professor
top_prof <- bu_data %>% group_by(prof_name) %>% mutate(avg_hw_lvl=round(mean(hw_level), digits = 2)) %>% ungroup() %>% filter(str_length(course_name) == 5) %>% summarise(prof_name, course_name, rate_prof, tDept, avg_hw_lvl) %>% group_by(course_name) %>% mutate(rank = dense_rank(desc(rate_prof))) %>% filter(rank == 1) %>% ungroup() %>% arrange(tDept) %>% summarise(prof_name, course_name, rate_prof, tDept, avg_hw_lvl) %>% unique()

departments <- top_prof %>% pull(tDept) %>% unique() %>% sort()
courses <- top_prof %>% pull(course_name) %>% unique() %>% sort()


linebreaks <- function(n){HTML(strrep(br(), n))}

ui <- navbarPage("NACC: BU",
                 theme = shinytheme("sandstone"),
                 tabPanel( "Rank by professors",
                           sidebarLayout(
                             sidebarPanel(
                               selectInput(inputId = "dept", label = "Department", choices = dept, multiple = FALSE, selected = "Accounting department")
                             ),
                             mainPanel(
                               plotlyOutput("distPlot"),
                               p(linebreaks(3)),
                               h3("Professor ranked by average"),
                               h6("overall score = average rating - average difficulty level, arranged in decreasing order"),
                               p(linebreaks(1)),
                               DT::dataTableOutput("table3")
                             ))
                           
                 ),
                 tabPanel( "Rank by courses",
                           sidebarLayout(
                             sidebarPanel(
                               selectInput(inputId = "dept2", label = "Department", choices = dept, multiple = FALSE, selected = "Accounting department")
                             ),
                             mainPanel(
                               plotlyOutput("distPlot2"),
                               p(linebreaks(3)),
                               h3("Courses ranked by average"),
                               h6("overall score = average homework level + average difficulty level, arranged in increasing order"),
                               p(linebreaks(1)),
                               DT::dataTableOutput("table2"))
                           )
                 ),
                 tabPanel( "Highest Ranked Professors（by courses）",
                           fluidRow(
                             column(4,
                                    selectInput(inputId = "dept3", label = "Department", choices = dept, multiple = FALSE, selected = "Accounting department")
                             )
                           ),
                           # Create a new row for the table.
                           DT::dataTableOutput("table")
                 )
)


server <- function(input, output) {
  output$distPlot <- renderPlotly({
    p <- phy_prof %>% filter(tDept == input$dept) %>% ggplot(aes_string(x = "avg_rating", y = "avg_diff", color = "prof_name")) + geom_point(aes(text=sprintf("Professor: %s<br>Rating: %s <br>Difficulty: %s", prof_name, avg_rating, avg_diff))) + xlab("Average Rating") + ylab("Average Difficulty")  + labs(color='Professor')  + theme(legend.position='none', axis.text = element_text(family = "Roboto"), axis.title = element_text(family = "Roboto"))
    ggplotly(p,tooltip="text")#, tooltip = c("Professor name", "average rating", "average difficulty")) #%>% 
    # partial_bundle()
  })
  
  output$table3 <- DT::renderDataTable(DT::datatable({
    data3 <- phy_prof2 %>% filter(tDept == input$dept) %>% arrange(-overall_score) %>% rename(Department = tDept, 'Professor Name' = prof_name, 'Average Rating' = avg_rating, 'Average Difficulty' = avg_diff, 'Overall Score' = overall_score)
    data3 
  }, style = "bootstrap"))
  
  output$distPlot2 <- renderPlotly({
    p <- courses_rate %>% filter(tDept == input$dept2) %>% ggplot(aes_string(x = "avg_hw_lvl", y = "avg_diff", color = "course_name")) + geom_point(aes(text=sprintf("Course Name: %s<br>Homework Level: %s <br>Difficulty: %s", course_name, avg_hw_lvl, avg_diff))) + xlab("Average Homework Level") + ylab("Average Difficulty")  + labs(color='courses') + theme(legend.position='none', axis.text = element_text(family = "Roboto"), axis.title = element_text(family = "Roboto"))
    ggplotly(p,tooltip="text") #%>% 
    #partial_bundle()
  })
  
  output$table2 <- DT::renderDataTable(DT::datatable({
    data2 <- courses_rate2 %>% filter(tDept == input$dept2) %>% arrange(overall_score) %>% rename(Department = tDept, 'Course' = course_name, 'Average HW Level' = avg_hw_lvl, 'Average Difficulty' = avg_diff, 'Overall Score' = overall_score)
    data2 
  }, style = "bootstrap"))
  
  output$table <- DT::renderDataTable(DT::datatable({
    data <- top_prof %>% filter(top_prof$tDept == input$dept3) %>% rename(Department = tDept, 'Professor Name' = prof_name, 'Professor Rating' = rate_prof, 'Course Name' = course_name, 'Avg HW level' = avg_hw_lvl)
    data
  }))
}

shinyApp(ui = ui, server = server)

