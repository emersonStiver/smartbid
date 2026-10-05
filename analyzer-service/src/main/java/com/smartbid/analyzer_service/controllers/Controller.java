package com.smartbid.analyzer_service.controllers;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;


@RestController 
@RequestMapping("/api/v1/analyzer-service")
public class Controller {
        
    @GetMapping("/testEndpoint")
    public String getMethodName() { return "Hello from Analyzer Service!";
    }
        
    @GetMapping("/testKaren")
    public String getMethodName2() {
        return "Hi Everybody, we are humans from earth, we come in peace";
    }

    @GetMapping("/testEmerson")
    public String getMethodName3() {
        return "Hi from colombia";
    }
    
    
    
}